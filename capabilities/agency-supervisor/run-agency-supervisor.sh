#!/usr/bin/env bash
set -euo pipefail

PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export KODY_STORE_CAPABILITIES_ROOT="$(dirname "$PROFILE_DIR")"

node --input-type=module <<'NODE'
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
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
const localRoot = process.env.KODY_STATE_ROOT;
const now = process.env.KODY_SUPERVISOR_NOW || new Date().toISOString();
const nowMs = Date.parse(now);
const maxAgeMs = 2 * 60 * 60 * 1000;

function gh(args) {
  return execFileSync("gh", args, { encoding: "utf8" }).trim();
}

function localFile(relative) {
  return join(localRoot, statePath, relative);
}

function readJson(relative) {
  if (localRoot) {
    const file = localFile(relative);
    return existsSync(file) ? JSON.parse(readFileSync(file, "utf8")) : null;
  }
  try {
    const raw = gh(["api", "--method", "GET", `repos/${stateOwner}/${stateRepo}/contents/${statePath}/${relative}`, "-f", `ref=${stateBranch}`]);
    const payload = JSON.parse(raw);
    return JSON.parse(Buffer.from(payload.content, "base64").toString("utf8"));
  } catch {
    return null;
  }
}

function listState(relative) {
  if (localRoot) {
    const dir = localFile(relative);
    if (!existsSync(dir)) return [];
    return readdirSync(dir, { withFileTypes: true }).map((entry) => ({ name: entry.name, type: entry.isDirectory() ? "dir" : "file" }));
  }
  try {
    return JSON.parse(gh(["api", "--method", "GET", `repos/${stateOwner}/${stateRepo}/contents/${statePath}/${relative}`, "-f", `ref=${stateBranch}`]));
  } catch {
    return [];
  }
}

function readText(relative) {
  if (localRoot) {
    const file = localFile(relative);
    return existsSync(file) ? readFileSync(file, "utf8") : null;
  }
  try {
    const raw = gh(["api", "--method", "GET", `repos/${stateOwner}/${stateRepo}/contents/${statePath}/${relative}`, "-f", `ref=${stateBranch}`]);
    return Buffer.from(JSON.parse(raw).content, "base64").toString("utf8");
  } catch {
    return null;
  }
}

function writeObservation(id, value) {
  const content = `${JSON.stringify(value, null, 2)}\n`;
  if (localRoot) {
    const file = localFile(`agency/observations/${id}.json`);
    mkdirSync(join(file, ".."), { recursive: true });
    writeFileSync(file, content);
    return;
  }
  const apiPath = `repos/${stateOwner}/${stateRepo}/contents/${statePath}/agency/observations/${id}.json`;
  let sha = null;
  try { sha = JSON.parse(gh(["api", "--method", "GET", apiPath, "-f", `ref=${stateBranch}`])).sha || null; } catch {}
  const args = ["api", "--method", "PUT", apiPath, "-f", `message=agency supervisor: ${id}`, "-f", `branch=${stateBranch}`, "-f", `content=${Buffer.from(content).toString("base64")}`];
  if (sha) args.push("-f", `sha=${sha}`);
  gh(args);
}

function compactTime(value) {
  return value.toLowerCase().replace(/[^a-z0-9]/g, "");
}

function ageViolation(code, message, observedAt) {
  const age = Date.parse(observedAt);
  return Number.isFinite(age) && nowMs - age <= maxAgeMs
    ? null
    : { code, message, observedAt };
}

function latestObservation() {
  return listState("agency/observations")
    .filter((entry) => entry.type === "file" && entry.name.endsWith(".json") && !entry.name.startsWith("obs-supervisor-"))
    .map((entry) => readJson(`agency/observations/${entry.name}`))
    .filter((value) => value && typeof value.observedAt === "string")
    .sort((a, b) => Date.parse(b.observedAt) - Date.parse(a.observedAt))[0] || null;
}

function latestFindings() {
  return listState("reports")
    .filter((entry) => entry.type === "dir")
    .flatMap((entry) => {
      const runs = listState(`reports/${entry.name}/runs`)
        .filter((run) => run.type === "file" && run.name.endsWith(".md"))
        .sort((a, b) => a.name.localeCompare(b.name));
      const latest = runs.at(-1);
      if (!latest) return [];
      const text = readText(`reports/${entry.name}/runs/${latest.name}`);
      const json = text?.match(/## Report data\s*\n```json\s*\n([\s\S]*?)\n```/)?.[1];
      if (!json || !/^reportType:\s*finding\s*$/m.test(text)) return [];
      try {
        const data = JSON.parse(json);
        return data.finding ? [{ ...data.finding, reportRunId: latest.name }] : [];
      } catch { return []; }
    });
}

function checkLoopRuns(violations) {
  const index = readJson("runs/index.json");
  for (const loop of ["agency-observer", "agency-operating-loop"]) {
    const run = (index?.runs || [])
      .filter((item) => item.subjectId === loop || item.workflow === loop)
      .sort((a, b) => Date.parse(b.updatedAt || b.startedAt || "") - Date.parse(a.updatedAt || a.startedAt || ""))[0];
    if (!run) {
      violations.push({ code: "missing-loop-evidence", message: `${loop} has no recorded run` });
    } else if (run.status !== "success") {
      violations.push({ code: "failed-loop", message: `${loop} last run was ${run.status}` });
    } else {
      const violation = ageViolation("stale-loop-evidence", `${loop} has no recent successful evidence`, run.updatedAt || run.startedAt);
      if (violation) violations.push(violation);
    }
  }
}

const violations = [];
const repairs = [];
const pendingApproval = [];
const observation = latestObservation();
if (!observation) {
  violations.push({ code: "missing-observation", message: "No non-supervisor agency observation exists" });
} else {
  const violation = ageViolation("stale-observation", "The latest agency observation is older than two hours", observation.observedAt);
  if (violation) violations.push(violation);
}

for (const finding of latestFindings()) {
  if (finding.status === "open" && !finding.operatorActivityAt) {
    violations.push({ code: "idle-finding", message: `${finding.id} has no recent operator activity` });
  } else if (finding.status === "open") {
    const violation = ageViolation("idle-finding", `${finding.id} has no recent operator activity`, finding.operatorActivityAt);
    if (violation) violations.push(violation);
  }
  if (finding.observationId && !readJson(`agency/observations/${finding.observationId}.json`)) {
    violations.push({ code: "finding-observation-mismatch", message: `${finding.id} references missing observation ${finding.observationId}` });
  }
}

for (const entry of listState("operations").filter((item) => item.type === "dir")) {
  const operation = readJson(`operations/${entry.name}/operation.json`);
  if (operation?.status === "proposed" || operation?.status === "provisioning") {
    const violation = ageViolation("stuck-operation", `${entry.name} has been ${operation.status} for more than two hours`, operation.updatedAt || operation.createdAt);
    if (violation) violations.push(violation);
  }
}

checkLoopRuns(violations);

const status = violations.some((item) => ["missing-observation", "stale-observation", "missing-loop-evidence", "stale-loop-evidence", "finding-observation-mismatch", "stuck-operation"].includes(item.code))
  ? "blocked"
  : violations.length > 0 ? "unhealthy" : "healthy";
const supervision = {
  subject: "agency-supervisor",
  status,
  checkedAt: now,
  healthy: status === "healthy" ? ["observations", "findings", "operations", "loops", "reports"] : [],
  violations,
  repairs,
  pendingApproval,
  nextCheckAt: new Date(nowMs + 60 * 60 * 1000).toISOString(),
};
const observationId = `obs-supervisor-${compactTime(now)}`;
writeObservation(observationId, { version: 1, id: observationId, observerId: "agency-supervisor", capability: "agency-supervisor", subject: supervision.subject, status, summary: `Agency supervision is ${status}`, supervision, observedAt: now });
const resultStatus = status === "healthy" ? "pass" : status === "blocked" ? "blocked" : "fail";
console.log(`KODY_CAPABILITY_RESULT=${JSON.stringify({ status: resultStatus, summary: `Agency supervision is ${status}`, facts: { supervision }, artifacts: [{ label: "supervisor observation", value: observationId }], blockers: status === "blocked" ? violations.map((item) => item.message) : [] })}`);
console.log(`AGENCY_SUPERVISOR status=${status} violations=${violations.length} repairs=${repairs.length} observation=${observationId}`);
NODE
