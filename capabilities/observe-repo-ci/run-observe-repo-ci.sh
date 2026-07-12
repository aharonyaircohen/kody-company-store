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
const now = process.env.KODY_OBSERVER_NOW || new Date().toISOString();

function gh(args) {
  return execFileSync("gh", args, { encoding: "utf8" }).trim();
}

let run = null;
let status = process.env.KODY_OBSERVER_CI_STATUS || "";
if (!status) {
  const output = gh([
    "run", "list", "--repo", `${owner}/${repo}`, "--branch", branch,
    "--limit", "1", "--json", "conclusion,status,url,name,databaseId",
  ]);
  run = JSON.parse(output || "[]")[0] || null;
  status = !run
    ? "unknown"
    : run.status !== "completed"
      ? "unknown"
      : run.conclusion === "success"
        ? "healthy"
        : "unhealthy";
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
    kind: "workflow-run",
    label: run.name || "GitHub Actions",
    status: run.conclusion || run.status,
    ...(run.url ? { url: run.url } : {}),
    ...(run.databaseId ? { value: Number(run.databaseId) } : {}),
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
const resolved = status === "healthy";
const finding = {
  version: 1,
  id: findingId,
  observerId: "agency-observer",
  subject: `repo-ci:${branch}`,
  title: previous?.title || "Default branch CI is failing",
  expectation: "Default branch CI is green",
  actual: summary,
  severity: "high",
  status: resolved ? "resolved" : (previous?.status || "open"),
  phase: resolved ? "closed" : (previous?.phase || "observed"),
  observationIds: ids,
  createdAt: previous?.createdAt || now,
  updatedAt: now,
  ...(resolved ? { resolvedAt: now } : {}),
  ...(previous?.decision ? { decision: previous.decision } : {}),
  ...(previous?.deliveryRunId ? { deliveryRunId: previous.deliveryRunId } : {}),
  ...(previous?.learningIds ? { learningIds: previous.learningIds } : {}),
};
writeJson(`agency/findings/${findingId}.json`, finding, `finding: ${finding.status} ${findingId}`);

console.log(`REPO_CI_OBSERVED status=${status} observation=${observationId} finding=${findingId}`);
NODE
