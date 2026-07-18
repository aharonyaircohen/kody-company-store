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
const now = process.env.KODY_AGENCY_FLOW_NOW || new Date().toISOString();
const staleHours = Number(process.env.KODY_AGENCY_FLOW_STALE_HOURS || 24);
const staleBefore = new Date(new Date(now).getTime() - staleHours * 3600_000);

function gh(args) {
  return execFileSync("gh", args, { encoding: "utf8" }).trim();
}

function isStale(timestamp) {
  const parsed = new Date(String(timestamp || ""));
  return Number.isFinite(parsed.getTime()) && parsed < staleBefore;
}

let items;
if (process.env.KODY_AGENCY_FLOW_ITEMS_JSON) {
  items = JSON.parse(process.env.KODY_AGENCY_FLOW_ITEMS_JSON);
} else {
  items = [];

  // Stale agent review PRs on the state repo that touch this repo's state path.
  try {
    const pulls = JSON.parse(gh([
      "api", `repos/${stateOwner}/${stateRepo}/pulls?state=open&per_page=50`,
    ]));
    for (const pull of pulls.filter((candidate) => isStale(candidate?.created_at)).slice(0, 20)) {
      let files = [];
      try {
        files = JSON.parse(gh([
          "api", `repos/${stateOwner}/${stateRepo}/pulls/${pull.number}/files?per_page=100`,
        ]));
      } catch {}
      const touchesRepo = files.some((file) => String(file?.filename || "").startsWith(`${statePath}/`));
      if (!touchesRepo) continue;
      items.push({
        kind: "stale-review-pr",
        label: `Review PR #${pull.number} open since ${pull.created_at}: ${pull.title}`,
        url: pull.html_url,
      });
    }
  } catch {}

  // Open capability request issues nobody has answered.
  try {
    const issues = JSON.parse(gh([
      "api", `repos/${owner}/${repo}/issues?state=open&per_page=100`,
    ]));
    for (const issue of issues) {
      if (issue.pull_request) continue;
      const title = String(issue.title || "");
      if (/^\[[^\]]+\]/.test(title) && isStale(issue.created_at)) {
        items.push({
          kind: "unanswered-request",
          label: `Request issue #${issue.number} open since ${issue.created_at}: ${title}`,
          url: issue.html_url,
        });
      } else if (String(issue.body || "").includes("kody-track:") && isStale(issue.updated_at)) {
        items.push({
          kind: "idle-finding",
          label: `Finding issue #${issue.number} idle since ${issue.updated_at}: ${title}`,
          url: issue.html_url,
        });
      }
    }
  } catch {}
}

const status = items.length === 0 ? "healthy" : "unhealthy";
const compactTime = now.toLowerCase().replace(/[^a-z0-9]/g, "");
const observationId = `obs-agency-flow-${compactTime}`;
const findingId = "finding-agency-flow";
const summary = status === "healthy"
  ? "Agency pipeline is flowing"
  : `Agency pipeline has ${items.length} stale item${items.length === 1 ? "" : "s"}`;
const observation = {
  version: 1,
  id: observationId,
  observerId: "agency-observer",
  capability: "observe-agency-flow",
  subject: `agency-flow:${repo}`,
  status,
  summary,
  evidence: items.length > 0
    ? items.slice(0, 10).map((item) => ({
        kind: item.kind,
        label: item.label,
        status: "stale",
        ...(item.url ? { url: item.url } : {}),
      }))
    : [{ kind: "agency-flow", label: summary, status }],
  observedAt: now,
};

const localRoot = process.env.KODY_STATE_ROOT;
function localFile(relative) {
  return join(localRoot, statePath, relative);
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

function findingReportExists() {
  if (localRoot) {
    const dir = join(localRoot, statePath, "reports", findingId, "runs");
    return existsSync(dir);
  }
  try {
    gh(["api", "--method", "GET", `repos/${stateOwner}/${stateRepo}/contents/${statePath}/reports/${findingId}/runs`, "-f", `ref=${stateBranch}`]);
    return true;
  } catch {
    return false;
  }
}

const shouldPublishFinding = status !== "healthy" || findingReportExists();
const finding = shouldPublishFinding ? {
  id: findingId,
  observerId: "agency-observer",
  subject: `agency-flow:${repo}`,
  title: "Agency pipeline has stale items",
  expectation: "Agency review PRs, requests, and findings keep moving",
  actual: summary,
  severity: "medium",
  status: status === "healthy" ? "resolved" : "open",
  observationId,
  observedAt: now,
} : undefined;
const result = {
  version: 1,
  status: status === "healthy" ? "pass" : "fail",
  summary,
  facts: {
    observation,
    ...(finding ? { finding } : {}),
  },
  artifacts: observation.evidence
    .filter((item) => item.url)
    .map((item) => ({ label: item.label, url: item.url })),
  missingEvidence: [],
  blockers: status === "unhealthy" ? [summary] : [],
};
console.log(`KODY_CAPABILITY_RESULT=${JSON.stringify(result)}`);
console.log(`AGENCY_FLOW_OBSERVED status=${status} observation=${observationId} finding=${finding ? findingId : "none"}`);
NODE
