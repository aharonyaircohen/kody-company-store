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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_STORE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

AI_AGENCY_HEALTH_MATRIX_DRY_RUN="$DRY_RUN" \
AI_AGENCY_HEALTH_MATRIX_SCRIPT_DIR="$SCRIPT_DIR" \
KODY_STORE_ROOT="${KODY_STORE_ROOT:-$DEFAULT_STORE_ROOT}" \
node <<'NODE'
const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const cwd = process.cwd();
const dryRun = process.env.AI_AGENCY_HEALTH_MATRIX_DRY_RUN === "1";
const storeRoot = path.resolve(process.env.KODY_STORE_ROOT || "");
const stateRoot = process.env.KODY_STATE_ROOT ? path.resolve(process.env.KODY_STATE_ROOT) : "";
const reportSlug = "ai-agency-health-matrix";
const generatedAt = new Date().toISOString();
const runId = generatedAt.replace(/\.\d{3}Z$/, "Z").replace(/:/g, "-");
const reportFile = `reports/${reportSlug}/runs/${runId}.md`;
const defaultStateBranch = "main";
const rows = [];

function exists(root, rel) {
  return fs.existsSync(path.join(root, rel));
}

function readText(root, rel) {
  return fs.readFileSync(path.join(root, rel), "utf8");
}

function readJson(root, rel) {
  return JSON.parse(readText(root, rel));
}

function listDirs(root, rel) {
  const dir = path.join(root, rel);
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();
}

function listFiles(root, rel, suffix) {
  const dir = path.join(root, rel);
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir, { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith(suffix))
    .map((entry) => entry.name.slice(0, -suffix.length))
    .sort();
}

function asStringList(value) {
  if (Array.isArray(value)) return value.filter((item) => typeof item === "string" && item.length > 0);
  if (typeof value === "string" && value.length > 0) return [value];
  return [];
}

function activeGoalSlug(value) {
  if (typeof value === "string") return value;
  if (value && typeof value === "object" && typeof value.template === "string") return value.template;
  return "";
}

function normalizeRepo(value) {
  return String(value || "")
    .replace(/^https:\/\/github\.com\//, "")
    .replace(/\.git$/, "")
    .replace(/^\/+|\/+$/g, "");
}

function resolveStateBranch(config) {
  const branch = typeof config?.state?.branch === "string" ? config.state.branch.trim() : "";
  return branch || defaultStateBranch;
}

function row(area, expected, actual, health, proof, owner, nextAction) {
  rows.push({
    area,
    expected,
    actual: actual || "",
    health,
    proof: proof || "",
    owner,
    nextAction,
  });
}

function hasLocalCapability(slug) {
  return exists(cwd, `.kody/capabilities/${slug}/profile.json`);
}

function hasStoreCapability(slug) {
  return exists(storeRoot, `.kody/capabilities/${slug}/profile.json`);
}

function hasLocalAgent(slug) {
  return exists(cwd, `.kody/agents/${slug}.md`) || exists(cwd, `.kody/staff/${slug}.md`);
}

function hasStoreAgent(slug) {
  return exists(storeRoot, `.kody/agents/${slug}.md`) || exists(storeRoot, `.kody/staff/${slug}.md`);
}

function hasLocalGoal(slug) {
  return (
    exists(cwd, `.kody/goals/templates/${slug}/state.json`) ||
    exists(cwd, `.kody/goals/instances/${slug}/state.json`) ||
    exists(cwd, `.kody/todos/${slug}.json`)
  );
}

function hasStoreGoal(slug) {
  return exists(storeRoot, `.kody/goals/templates/${slug}/state.json`);
}

function readConfig() {
  if (!exists(cwd, "kody.config.json")) {
    row("config", "kody.config.json", "missing", "missing", "", "consumer repo", "add repo Kody config");
    return {};
  }
  try {
    const config = readJson(cwd, "kody.config.json");
    row("config", "kody.config.json", "valid JSON", "healthy", "kody.config.json", "consumer repo", "none");
    return config;
  } catch (error) {
    row("config", "kody.config.json", "invalid JSON", "failing", String(error.message || error), "consumer repo", "fix config JSON");
    return {};
  }
}

function resolveRepo(config) {
  const owner = typeof config?.github?.owner === "string" ? config.github.owner : "";
  const repoName = typeof config?.github?.repo === "string" ? config.github.repo : "";
  if (owner && repoName) return `${owner}/${repoName}`;

  const result = spawnSync("gh", ["repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner"], {
    cwd,
    encoding: "utf8",
  });
  if (result.status === 0 && result.stdout.trim()) return result.stdout.trim();
  return path.basename(cwd);
}

function inspectStore() {
  if (!storeRoot || !fs.existsSync(storeRoot)) {
    row("store", "Store catalog", "not found", "unknown", "KODY_STORE_ROOT is not set or not readable", "Store", "provide Store root");
    return;
  }
  if (!exists(storeRoot, "kody-store.json")) {
    row("store", "Store catalog", "missing kody-store.json", "unknown", storeRoot, "Store", "verify Store checkout");
    return;
  }
  row("store", "Store catalog", "available", "healthy", storeRoot, "Store", "none");
}

function inspectOperators(config) {
  const operators = asStringList(config?.github?.operators);
  if (operators.length > 0) {
    row("operators", "github.operators", operators.join(", "), "healthy", "kody.config.json", "consumer repo", "none");
  } else {
    row("operators", "github.operators", "missing", "missing", "recommendations may not mention an operator", "consumer repo", "set explicit operators");
  }
}

function inspectState(config) {
  const stateRepo = normalizeRepo(config?.state?.repo || config?.stateRepo || "");
  const statePath = String(config?.state?.path || config?.statePath || "").replace(/^\/+|\/+$/g, "");
  if (!stateRepo || !statePath) {
    row("state", "state.repo + state.path", "missing", "missing", "kody.config.json", "consumer repo", "configure state repo");
    return;
  }
  row("state", "state.repo + state.path", `${stateRepo}/${statePath}`, "healthy", "kody.config.json", "consumer repo", "none");
}

function resolveStateBase(config) {
  const statePath = String(config?.state?.path || config?.statePath || "").replace(/^\/+|\/+$/g, "");
  if (!stateRoot || !statePath) return "";
  return path.join(stateRoot, statePath);
}

function inspectActiveAgents(activeAgents) {
  if (activeAgents.length === 0) {
    row("agents", "company.activeAgents", "empty", "unknown", "kody.config.json", "consumer repo", "decide active agents");
    return;
  }
  for (const slug of activeAgents) {
    if (hasLocalAgent(slug)) {
      row("agents", slug, "local", "repo-local", `.kody/agents/${slug}.md`, "consumer repo", "confirm local override is intentional");
    } else if (hasStoreAgent(slug)) {
      row("agents", slug, "store", "healthy", `.kody/agents/${slug}.md`, "Store", "none");
    } else {
      row("agents", slug, "missing", "missing", "active agent is not local or in Store", "consumer repo", "add agent or remove activation");
    }
  }
}

function inspectActiveCapabilities(activeCapabilities) {
  if (activeCapabilities.length === 0) {
    row("capabilities", "company.activeCapabilities", "empty", "unknown", "kody.config.json", "consumer repo", "decide active capabilities");
    return;
  }
  for (const slug of activeCapabilities) {
    if (hasLocalCapability(slug)) {
      const alsoStore = hasStoreCapability(slug);
      row(
        "capabilities",
        slug,
        alsoStore ? "local override over Store" : "local only",
        "repo-local",
        `.kody/capabilities/${slug}/profile.json`,
        "consumer repo",
        alsoStore ? "confirm override is intentional" : "keep local or promote to Store",
      );
    } else if (hasStoreCapability(slug)) {
      row("capabilities", slug, "store", "healthy", `.kody/capabilities/${slug}/profile.json`, "Store", "none");
    } else {
      row("capabilities", slug, "missing", "missing", "active capability is not local or in Store", "consumer repo", "add capability or remove activation");
    }
  }
}

function inspectActiveGoals(activeGoals, stateBase) {
  if (activeGoals.length === 0) {
    row("goals", "company.activeGoals", "empty", "unknown", "kody.config.json", "consumer repo", "decide active goals");
    return;
  }
  for (const item of activeGoals) {
    const slug = activeGoalSlug(item);
    if (!slug) {
      row("goals", JSON.stringify(item), "unsupported activation", "failing", "kody.config.json", "consumer repo", "fix active goal entry");
    } else if (stateBase && exists(stateBase, `goals/instances/${slug}/state.json`)) {
      row("goals", slug, "state repo instance", "healthy", path.join(stateBase, "goals", "instances", slug, "state.json"), "state repo", "none");
    } else if (stateBase && exists(stateBase, `todos/${slug}.json`)) {
      row("goals", slug, "state repo todo", "healthy", path.join(stateBase, "todos", `${slug}.json`), "state repo", "none");
    } else if (hasLocalGoal(slug)) {
      row("goals", slug, "local/runtime", "repo-local", `local goal or todo ${slug}`, "consumer repo", "confirm local runtime state is intentional");
    } else if (hasStoreGoal(slug)) {
      row("goals", slug, "store template", "healthy", `.kody/goals/templates/${slug}/state.json`, "Store", "none");
    } else {
      row("goals", slug, "missing", "missing", "active goal is not local/runtime or in Store", "consumer repo", "add goal or remove activation");
    }
  }
}

function inspectJobs(stateBase) {
  if (stateBase && fs.existsSync(stateBase)) {
    const jobFiles = listFiles(stateBase, "jobs", ".md");
    const stateFiles = listFiles(stateBase, "jobs", ".state.json");
    if (jobFiles.length === 0 && stateFiles.length === 0) {
      row("jobs", "state jobs", "none", "not-relevant", path.join(stateBase, "jobs"), "state repo", "none");
      return;
    }
    row(
      "jobs",
      "state jobs",
      `${jobFiles.length} job(s), ${stateFiles.length} state file(s)`,
      "healthy",
      path.join(stateBase, "jobs"),
      "state repo",
      "verify freshness from job run history",
    );
    return;
  }

  if (stateRoot) {
    row("jobs", "state jobs", "state checkout unavailable", "unknown", stateRoot, "state repo", "verify KODY_STATE_ROOT and state.path");
    return;
  }

  const jobFiles = listFiles(cwd, ".kody/jobs", ".md");
  const stateFiles = listFiles(cwd, ".kody/jobs", ".state.json");
  if (jobFiles.length === 0 && stateFiles.length === 0) {
    row("jobs", ".kody/jobs", "state checkout not provided", "unknown", "set KODY_STATE_ROOT to inspect external state jobs", "state repo", "provide state checkout for runtime proof");
    return;
  }
  row(
    "jobs",
    ".kody/jobs",
    `${jobFiles.length} job(s), ${stateFiles.length} state file(s)`,
    "unknown",
    ".kody/jobs",
    "state repo",
    "verify freshness from job run history",
  );
}

function inspectLocalOverrides() {
  const localCapabilities = listDirs(cwd, ".kody/capabilities");
  const shadowing = localCapabilities.filter((slug) => hasStoreCapability(slug));
  if (shadowing.length === 0) {
    row("overrides", "local capability shadows", "none", "healthy", ".kody/capabilities", "consumer repo", "none");
    return;
  }
  row(
    "overrides",
    "local capability shadows",
    shadowing.join(", "),
    "repo-local",
    ".kody/capabilities",
    "consumer repo",
    "confirm each shadow is intentional",
  );
}

const config = readConfig();
const repo = resolveRepo(config);
const company = config && typeof config.company === "object" && config.company ? config.company : {};
const activeAgents = asStringList(company.activeAgents);
const activeCapabilities = asStringList(company.activeCapabilities ?? company.activeExecutables);
const activeGoals = Array.isArray(company.activeGoals) ? company.activeGoals : asStringList(company.activeGoals);
const stateBase = resolveStateBase(config);

inspectStore();
inspectState(config);
inspectOperators(config);
inspectActiveAgents(activeAgents);
inspectActiveCapabilities(activeCapabilities);
inspectActiveGoals(activeGoals, stateBase);
inspectJobs(stateBase);
inspectLocalOverrides();

const countKeys = {
  healthy: "healthy",
  missing: "missing",
  unknown: "unknown",
  failing: "failing",
  stale: "stale",
  "repo-local": "repoLocal",
  "not-relevant": "notRelevant",
};
const counts = {
  healthy: 0,
  missing: 0,
  unknown: 0,
  failing: 0,
  stale: 0,
  repoLocal: 0,
  notRelevant: 0,
};
for (const item of rows) {
  const key = countKeys[item.health];
  if (key) counts[key] += 1;
}

const status = counts.failing > 0 || counts.missing > 0 ? "red" : counts.unknown > 0 || counts.stale > 0 || counts.repoLocal > 0 ? "yellow" : "green";
const reportData = {
  schemaVersion: 1,
  reportSlug,
  repo,
  generatedAt,
  status,
  counts,
  rows,
};

function mdCell(value) {
  return String(value ?? "").replace(/\|/g, "\\|").replace(/\n/g, " ");
}

const table = [
  "| area | expected | actual | health | proof | owner | nextAction |",
  "|---|---|---|---|---|---|---|",
  ...rows.map((item) =>
    `| ${mdCell(item.area)} | ${mdCell(item.expected)} | ${mdCell(item.actual)} | ${mdCell(item.health)} | ${mdCell(item.proof)} | ${mdCell(item.owner)} | ${mdCell(item.nextAction)} |`,
  ),
].join("\n");

const frontmatter = [
  "---",
  `slug: ${reportSlug}`,
  `generatedAt: "${generatedAt}"`,
  `repo: "${repo}"`,
  `status: ${status}`,
  "counts:",
  `  healthy: ${counts.healthy}`,
  `  missing: ${counts.missing}`,
  `  unknown: ${counts.unknown}`,
  `  failing: ${counts.failing}`,
  `  stale: ${counts.stale}`,
  `  repoLocal: ${counts.repoLocal}`,
  `  notRelevant: ${counts.notRelevant}`,
  "---",
  "",
].join("\n");

const report = `${frontmatter}# AI Agency Health Matrix

AI Agency Health: ${status.toUpperCase()}

| Signal | Count |
|---|---:|
| Healthy | ${counts.healthy} |
| Missing | ${counts.missing} |
| Unknown | ${counts.unknown} |
| Failing | ${counts.failing} |
| Stale | ${counts.stale} |
| Repo local | ${counts.repoLocal} |
| Not relevant | ${counts.notRelevant} |

${table}

\`\`\`json
${JSON.stringify(reportData, null, 2)}
\`\`\`
`;

function runGh(args, input) {
  return spawnSync("gh", args, {
    cwd,
    input,
    encoding: "utf8",
    maxBuffer: 10 * 1024 * 1024,
  });
}

function parseJsonOutput(result, label) {
  try {
    return JSON.parse(result.stdout);
  } catch {
    throw new Error(`${label} returned invalid JSON`);
  }
}

function isNotFound(result) {
  return result.status !== 0 && /Not Found|HTTP 404/i.test(`${result.stderr}\n${result.stdout}`);
}

function isAlreadyExists(result) {
  return result.status !== 0 && /Reference already exists|HTTP 422/i.test(`${result.stderr}\n${result.stdout}`);
}

function resolveStateTarget() {
  let currentRepo = "";
  const view = runGh(["repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner"]);
  if (view.status === 0) currentRepo = view.stdout.trim();

  const [owner, name] = (currentRepo || repo).split("/");
  const stateRepo = normalizeRepo(config?.state?.repo || config?.stateRepo || `${owner}/kody-state`);
  const statePath = String(config?.state?.path || config?.statePath || name || "").replace(/^\/+|\/+$/g, "");
  return {
    stateRepo,
    stateBranch: resolveStateBranch(config),
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

function writeReport() {
  const { stateRepo, stateBranch, reportPath } = resolveStateTarget();
  ensureStateBranch(stateRepo, stateBranch);
  const content = Buffer.from(report).toString("base64");
  const put = runGh([
    "api",
    "-X",
    "PUT",
    `/repos/${stateRepo}/contents/${reportPath}`,
    "-f",
    "message=chore(reports): add ai-agency-health-matrix run",
    "-f",
    `branch=${stateBranch}`,
    "-f",
    `content=${content}`,
  ]);
  if (put.status !== 0) throw new Error(put.stderr.trim() || put.stdout.trim() || "Could not write report");
  return { stateRepo, reportPath };
}

if (dryRun) {
  process.stdout.write(`${report}\n`);
  const { stateBranch } = resolveStateTarget();
  process.stdout.write(`DONE\nCOMMIT_MSG: chore(reports): add ai-agency-health-matrix run\nPR_SUMMARY:\n- Dry run only; no report write attempted.\n- Report path would be ${reportFile} on ${stateBranch}.\n- AI Agency Health: ${status.toUpperCase()} (${rows.length} rows).\n`);
} else {
  const target = writeReport();
  process.stdout.write(`DONE\nCOMMIT_MSG: chore(reports): add ai-agency-health-matrix run\nPR_SUMMARY:\n- Added ${target.reportPath} in ${target.stateRepo}.\n- AI Agency Health: ${status.toUpperCase()} (${rows.length} rows).\n`);
}
NODE
