#!/usr/bin/env bash
set -euo pipefail

node --input-type=module <<'NODE'
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const config = JSON.parse(readFileSync("kody.config.json", "utf8"));
const owner = config.github?.owner;
const repo = config.github?.repo;
if (!owner || !repo) throw new Error("kody.config.json must define github.owner and github.repo");

const stateSlug = String(config.state?.repo || `${owner}/kody-state`)
  .replace(/^https:\/\/github\.com\//, "")
  .replace(/\.git$/, "");
const [stateOwner, stateRepo] = stateSlug.split("/");
const statePath = String(config.state?.path || repo).replace(/^\/+|\/+$/g, "");
const stateBranch = config.state?.branch || "main";
const branch = config.git?.defaultBranch || config.github?.defaultBranch || "main";
const activeCapabilities = Array.isArray(config.company?.activeCapabilities)
  ? config.company.activeCapabilities.filter((value) => typeof value === "string")
  : [];
const now = process.env.KODY_OBSERVER_NOW || new Date().toISOString();

function gh(args) {
  return execFileSync("gh", args, { encoding: "utf8" }).trim();
}

let run = null;
let evidenceKind = "workflow-run";
let status = process.env.KODY_OBSERVER_CI_STATUS || "";
if (!status) {
  let commitStatus = null;
  try {
    if (process.env.KODY_OBSERVER_COMMIT_STATUS_JSON) {
      commitStatus = JSON.parse(process.env.KODY_OBSERVER_COMMIT_STATUS_JSON);
    } else {
      const sha = gh(["api", `repos/${owner}/${repo}/commits/${branch}`, "--jq", ".sha"]);
      commitStatus = JSON.parse(gh(["api", `repos/${owner}/${repo}/commits/${sha}/status`]));
    }
  } catch {}
  const statuses = Array.isArray(commitStatus?.statuses) ? commitStatus.statuses : [];
  if (statuses.length > 0) {
    const selected = statuses.find((candidate) => ["failure", "error"].includes(candidate?.state))
      || statuses.find((candidate) => candidate?.state === "pending")
      || statuses[0];
    run = {
      name: selected?.context || "Commit status",
      status: selected?.state === "pending" ? "in_progress" : "completed",
      conclusion: selected?.state || commitStatus.state || "pending",
      url: selected?.target_url || "",
      sha: commitStatus?.sha || "",
    };
    evidenceKind = "commit-status";
    status = ["failure", "error"].includes(commitStatus.state)
      ? "unhealthy"
      : commitStatus.state === "success"
        ? "healthy"
        : "unknown";
  } else {
    const output = process.env.KODY_OBSERVER_CI_RUNS_JSON || gh([
      "run", "list", "--repo", `${owner}/${repo}`, "--branch", branch,
      "--limit", "20", "--json", "conclusion,status,url,name,databaseId",
    ]);
    const runs = JSON.parse(output || "[]");
    run = runs.find((candidate) =>
      String(candidate?.name || "").trim().toLowerCase() !== "kody"
    ) || null;
    status = !run
      ? "unknown"
      : run.status !== "completed"
        ? "unknown"
        : run.conclusion === "success"
          ? "healthy"
          : "unhealthy";
  }
}
if (!["healthy", "unhealthy", "unknown"].includes(status)) {
  throw new Error(`Unsupported CI status: ${status}`);
}

const compactTime = now.toLowerCase().replace(/[^a-z0-9]/g, "");
const observationId = `obs-ci-${branch}-${compactTime}`;
const findingId = `finding-repo-ci-${branch}`;
const summary = status === "healthy"
  ? `Default branch CI is green`
  : status === "unhealthy"
    ? `Default branch CI is failing`
    : `Default branch CI state is unknown`;
const observation = {
  version: 1,
  id: observationId,
  observerId: "agency-observer",
  capability: "observe-repo-ci",
  subject: `repo-ci:${branch}`,
  status,
  summary,
  evidence: run ? [{
    kind: evidenceKind,
    label: run.name || "GitHub Actions",
    status: run.conclusion || run.status,
    ...(run.url ? { url: run.url } : {}),
    ...(run.databaseId ? { value: Number(run.databaseId) } : {}),
    ...(run.sha ? { value: run.sha } : {}),
  }] : [{ kind: "ci-status", label: summary, status }],
  observedAt: now,
};

const localRoot = process.env.KODY_STATE_ROOT;
function localFile(relative) {
  return join(localRoot, statePath, relative);
}
function readJson(relative) {
  if (localRoot) {
    const file = localFile(relative);
    return existsSync(file) ? JSON.parse(readFileSync(file, "utf8")) : null;
  }
  const apiPath = `repos/${stateOwner}/${stateRepo}/contents/${statePath}/${relative}`;
  try {
    const raw = gh(["api", "--method", "GET", apiPath, "-f", `ref=${stateBranch}`]);
    const payload = JSON.parse(raw);
    return JSON.parse(Buffer.from(payload.content, "base64").toString("utf8"));
  } catch {
    return null;
  }
}
function writeJson(relative, value, message) {
  const content = `${JSON.stringify(value, null, 2)}\n`;
  if (localRoot) {
    const file = localFile(relative);
    mkdirSync(join(file, ".."), { recursive: true });
    writeFileSync(file, content);
    return;
  }
  const apiPath = `repos/${stateOwner}/${stateRepo}/contents/${statePath}/${relative}`;
  let sha = null;
  try {
    sha = JSON.parse(gh(["api", "--method", "GET", apiPath, "-f", `ref=${stateBranch}`])).sha || null;
  } catch {}
  const args = [
    "api", "--method", "PUT", apiPath,
    "-f", `message=${message}`,
    "-f", `branch=${stateBranch}`,
    "-f", `content=${Buffer.from(content).toString("base64")}`,
  ];
  if (sha) args.push("-f", `sha=${sha}`);
  gh(args);
}

writeJson(`agency/observations/${observationId}.json`, observation, `observe: ${summary}`);

const previous = readJson(`agency/findings/${findingId}.json`);
if (status === "healthy" && !previous) {
  console.log(`REPO_CI_OBSERVED status=${status} observation=${observationId} finding=none`);
  process.exit(0);
}
const ids = [...new Set([...(previous?.observationIds || []), observationId])].slice(-100);
const readyForVerification = status === "healthy";
const remainsClosed = readyForVerification && (
  previous?.phase === "closed" || previous?.status === "resolved"
);
const decisionAction = previous?.decision?.action;
const decisionUnavailable = !readyForVerification
  && previous?.phase === "deciding"
  && typeof decisionAction === "string"
  && !activeCapabilities.includes(decisionAction);
const shouldReopen = !readyForVerification && (
  decisionUnavailable ||
  previous?.phase === "verifying" ||
  previous?.phase === "closed" ||
  previous?.status === "resolved"
);
const preserveOperation = readyForVerification || (!shouldReopen && previous?.phase !== "observed");
const finding = {
  version: 1,
  id: findingId,
  observerId: "agency-observer",
  subject: `repo-ci:${branch}`,
  title: previous?.title || "Default branch CI is failing",
  expectation: "Default branch CI is green",
  actual: summary,
  severity: "high",
  status: remainsClosed ? "resolved" : readyForVerification ? "in_progress" : shouldReopen ? "open" : (previous?.status || "open"),
  phase: remainsClosed ? "closed" : readyForVerification ? "verifying" : shouldReopen ? "observed" : (previous?.phase || "observed"),
  observationIds: ids,
  createdAt: previous?.createdAt || now,
  updatedAt: now,
  ...(preserveOperation && previous?.decision ? { decision: previous.decision } : {}),
  ...(preserveOperation && previous?.deliveryRunId ? { deliveryRunId: previous.deliveryRunId } : {}),
  ...(previous?.learningIds ? { learningIds: previous.learningIds } : {}),
  ...(remainsClosed && previous?.resolvedAt ? { resolvedAt: previous.resolvedAt } : {}),
};
writeJson(`agency/findings/${findingId}.json`, finding, `finding: ${finding.status} ${findingId}`);

console.log(`REPO_CI_OBSERVED status=${status} observation=${observationId} finding=${findingId}`);
NODE
