#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

command -v node >/dev/null 2>&1 || {
  printf 'FAILED: node is required\n'
  exit 1
}

command -v gh >/dev/null 2>&1 || {
  printf 'FAILED: gh is required\n'
  exit 1
}

AGENCY_BOUNDARY_REPORT_DRY_RUN="$DRY_RUN" node <<'NODE'
const fs = require("node:fs");
const { spawnSync } = require("node:child_process");

const cwd = process.cwd();
const dryRun = process.env.AGENCY_BOUNDARY_REPORT_DRY_RUN === "1";
const reportSlug = "agency-boundary-report";
const generatedAt = new Date().toISOString();
const runId = generatedAt.replace(/\.\d{3}Z$/, "Z").replace(/:/g, "-");
const reportFile = `reports/${reportSlug}/runs/${runId}.md`;
const marker = "KODY_AGENCY_BOUNDARY_EVAL=";
const runLimit = Number(process.env.AGENCY_BOUNDARY_REPORT_RUN_LIMIT || 25);

function runGh(args, input) {
  return spawnSync("gh", args, {
    cwd,
    input,
    encoding: "utf8",
    maxBuffer: 20 * 1024 * 1024,
  });
}

function readJsonIfExists(file) {
  if (!fs.existsSync(file)) return {};
  try {
    const parsed = JSON.parse(fs.readFileSync(file, "utf8"));
    return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : {};
  } catch {
    return {};
  }
}

function normalizeRepo(value) {
  return String(value || "")
    .replace(/^https:\/\/github\.com\//, "")
    .replace(/\.git$/, "")
    .replace(/^\/+|\/+$/g, "");
}

function currentRepo() {
  const result = runGh(["repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner"]);
  return result.status === 0 ? result.stdout.trim() : "";
}

function parseJsonOutput(result, label) {
  try {
    return JSON.parse(result.stdout);
  } catch {
    throw new Error(`${label} returned invalid JSON`);
  }
}

function loadRecentRuns() {
  const result = runGh([
    "run",
    "list",
    "--limit",
    String(runLimit),
    "--json",
    "databaseId,displayTitle,workflowName,conclusion,status,createdAt,url",
  ]);
  if (result.status !== 0) {
    throw new Error(result.stderr.trim() || result.stdout.trim() || "Could not list workflow runs");
  }
  const parsed = parseJsonOutput(result, "gh run list");
  return Array.isArray(parsed) ? parsed : [];
}

function evalsFromLog(log) {
  const evals = [];
  for (const line of log.split(/\r?\n/)) {
    const index = line.indexOf(marker);
    if (index < 0) continue;
    const raw = line.slice(index + marker.length).trim();
    if (!raw) continue;
    try {
      const parsed = JSON.parse(raw);
      if (parsed && typeof parsed === "object" && parsed.version === 1) evals.push(parsed);
    } catch {
    }
  }
  return evals;
}

function collectEvalFacts(runs) {
  const facts = [];
  for (const run of runs) {
    if (!run || typeof run.databaseId !== "number") continue;
    const log = runGh(["run", "view", String(run.databaseId), "--log"]);
    if (log.status !== 0) continue;
    for (const item of evalsFromLog(log.stdout)) {
      facts.push({
        run: {
          id: run.databaseId,
          title: run.displayTitle || "",
          workflow: run.workflowName || "",
          conclusion: run.conclusion || "",
          status: run.status || "",
          createdAt: run.createdAt || "",
          url: run.url || "",
        },
        eval: item,
      });
    }
  }
  return facts;
}

function findingRows(facts) {
  const rows = [];
  for (const fact of facts) {
    const findings = Array.isArray(fact.eval.findings) ? fact.eval.findings : [];
    for (const finding of findings) {
      rows.push({
        run: fact.run,
        capability: fact.eval.capability || "",
        capabilityKind: fact.eval.capabilityKind || "",
        rule: finding.rule || "",
        status: finding.status || "",
        message: finding.message || "",
        evidence: finding.evidence || {},
      });
    }
  }
  return rows;
}

function recommendation(row) {
  if (row.status !== "fail") return "none";
  if (row.rule === "observe-does-not-act") return "split action work into a separate act capability";
  if (row.rule === "verify-does-not-fix") return "move repair work behind a separate act capability";
  if (row.rule === "capability-does-not-own-goal-progress") {
    return "return parent-neutral result and let the goal or loop attach evidence";
  }
  return "inspect the capability contract";
}

function mdCell(value) {
  return String(value ?? "").replace(/\|/g, "\\|").replace(/\n/g, " ");
}

function reportFor(facts) {
  const rows = findingRows(facts);
  const failed = rows.filter((row) => row.status === "fail");
  const status = facts.length === 0 ? "yellow" : failed.length > 0 ? "red" : "green";
  const counts = {
    evals: facts.length,
    findings: rows.length,
    failed: failed.length,
    passed: rows.filter((row) => row.status === "pass").length,
  };
  const data = {
    schemaVersion: 1,
    reportSlug,
    generatedAt,
    status,
    counts,
    facts,
  };
  const table = [
    "| run | capability | kind | rule | status | message | recommendation |",
    "|---|---|---|---|---|---|---|",
    ...rows.map((row) =>
      `| ${mdCell(row.run.url || row.run.id)} | ${mdCell(row.capability)} | ${mdCell(row.capabilityKind)} | ${mdCell(row.rule)} | ${mdCell(row.status)} | ${mdCell(row.message)} | ${mdCell(recommendation(row))} |`,
    ),
  ].join("\n");
  const empty = facts.length === 0
    ? "\nNo `KODY_AGENCY_BOUNDARY_EVAL=` markers were found in the inspected workflow logs.\n"
    : "";
  return {
    status,
    counts,
    body: `---\nslug: ${reportSlug}\ngeneratedAt: "${generatedAt}"\nstatus: ${status}\n---\n\n# Agency Boundary Report\n\nAgency boundary health: ${status.toUpperCase()}\n${empty}\n| Signal | Count |\n|---|---:|\n| Eval runs | ${counts.evals} |\n| Findings | ${counts.findings} |\n| Failed | ${counts.failed} |\n| Passed | ${counts.passed} |\n\n${table}\n\n\`\`\`json\n${JSON.stringify(data, null, 2)}\n\`\`\`\n`,
  };
}

function isNotFound(result) {
  return result.status !== 0 && /Not Found|HTTP 404/i.test(`${result.stderr}\n${result.stdout}`);
}

function isAlreadyExists(result) {
  return result.status !== 0 && /Reference already exists|HTTP 422/i.test(`${result.stderr}\n${result.stdout}`);
}

function resolveStateTarget(config) {
  const repo = currentRepo();
  const [owner, name] = repo.split("/");
  const stateRepo = normalizeRepo(config?.state?.repo || config?.stateRepo || `${owner}/kody-state`);
  const statePath = String(config?.state?.path || config?.statePath || name || "").replace(/^\/+|\/+$/g, "");
  const stateBranch = String(config?.state?.branch || config?.stateBranch || "kody-state").trim();
  return {
    stateRepo,
    stateBranch,
    reportPath: `${statePath ? `${statePath}/` : ""}${reportFile}`,
  };
}

function ensureStateBranch(stateRepo, branch) {
  const stateRef = runGh(["api", `/repos/${stateRepo}/git/ref/heads/${branch}`]);
  if (stateRef.status === 0) return;
  if (!isNotFound(stateRef)) throw new Error(stateRef.stderr.trim() || stateRef.stdout.trim() || "Could not read state branch");

  const repoResult = runGh(["api", `/repos/${stateRepo}`]);
  if (repoResult.status !== 0) throw new Error(repoResult.stderr.trim() || repoResult.stdout.trim() || "Could not read state repo");
  const defaultBranch = String(parseJsonOutput(repoResult, "State repo").default_branch || "").trim();
  if (!defaultBranch) throw new Error("State repo default branch is missing");

  const defaultRef = runGh(["api", `/repos/${stateRepo}/git/ref/heads/${defaultBranch}`]);
  if (defaultRef.status !== 0) throw new Error(defaultRef.stderr.trim() || defaultRef.stdout.trim() || "Could not read default branch ref");
  const sha = String(parseJsonOutput(defaultRef, "Default branch ref").object?.sha || "").trim();
  if (!sha) throw new Error("Default branch ref SHA is missing");

  const create = runGh(
    ["api", "--method", "POST", `/repos/${stateRepo}/git/refs`, "--input", "-"],
    JSON.stringify({ ref: `refs/heads/${branch}`, sha }),
  );
  if (create.status !== 0 && !isAlreadyExists(create)) {
    throw new Error(create.stderr.trim() || create.stdout.trim() || "Could not create state branch");
  }
}

function writeReport(config, body) {
  const { stateRepo, stateBranch, reportPath } = resolveStateTarget(config);
  ensureStateBranch(stateRepo, stateBranch);
  const put = runGh([
    "api",
    "-X",
    "PUT",
    `/repos/${stateRepo}/contents/${reportPath}`,
    "-f",
    "message=chore(reports): add agency boundary report",
    "-f",
    `branch=${stateBranch}`,
    "-f",
    `content=${Buffer.from(body).toString("base64")}`,
  ]);
  if (put.status !== 0) throw new Error(put.stderr.trim() || put.stdout.trim() || "Could not write report");
  return { stateRepo, reportPath };
}

const config = readJsonIfExists("kody.config.json");
const runs = loadRecentRuns();
const facts = collectEvalFacts(runs);
const report = reportFor(facts);

if (dryRun) {
  process.stdout.write(`${report.body}\n`);
  process.stdout.write(`DONE\nPR_SUMMARY:\n- Dry run only; no report write attempted.\n- Agency boundary health: ${report.status.toUpperCase()} (${report.counts.failed} failed findings).\n`);
} else {
  const target = writeReport(config, report.body);
  process.stdout.write(`DONE\nPR_SUMMARY:\n- Added ${target.reportPath} in ${target.stateRepo}.\n- Agency boundary health: ${report.status.toUpperCase()} (${report.counts.failed} failed findings).\n`);
  process.stdout.write(`KODY_CAPABILITY_RESULT=${JSON.stringify({
    version: 1,
    status: report.status === "red" ? "fail" : "pass",
    summary: `Agency boundary health is ${report.status}.`,
    facts: { reportSlug, reportPath: target.reportPath, status: report.status, counts: report.counts },
    artifacts: [{ label: "Agency boundary report", path: target.reportPath }],
    missingEvidence: facts.length === 0 ? ["agencyBoundaryEvalFacts"] : [],
    blockers: [],
  })}\n`);
}
NODE
