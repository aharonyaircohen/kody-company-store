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

function readJsonIfExists(root, rel) {
  if (!exists(root, rel)) return null;
  try {
    const value = readJson(root, rel);
    return value && typeof value === "object" && !Array.isArray(value) ? value : null;
  } catch {
    return null;
  }
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

function readCapabilityProfile(slug) {
  return (
    readJsonIfExists(cwd, `.kody/capabilities/${slug}/profile.json`) ||
    readJsonIfExists(storeRoot, `.kody/capabilities/${slug}/profile.json`)
  );
}

function readGoalTemplate(slug) {
  return (
    readJsonIfExists(cwd, `.kody/goals/templates/${slug}/state.json`) ||
    readJsonIfExists(storeRoot, `.kody/goals/templates/${slug}/state.json`)
  );
}

function isAgentLoop(data) {
  return Boolean(
    data &&
      typeof data === "object" &&
      (data.scheduleMode === "agentLoop" ||
        data.type === "agentLoop" ||
        (typeof data.schedule === "string" && Array.isArray(data.capabilities))),
  );
}

function goalCapabilities(data) {
  return Array.isArray(data?.capabilities) ? data.capabilities.filter((item) => typeof item === "string" && item) : [];
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

function readStateGoal(stateBase, slug) {
  if (!stateBase) return null;
  const candidates = [
    {
      rel: `goals/instances/${slug}/state.json`,
      label: "state repo instance",
    },
    {
      rel: `todos/${slug}.json`,
      label: "state repo todo",
    },
  ];
  for (const candidate of candidates) {
    const data = readJsonIfExists(stateBase, candidate.rel);
    if (data) {
      return {
        data,
        label: candidate.label,
        path: path.join(stateBase, candidate.rel),
      };
    }
  }
  return null;
}

function latestReport(stateBase, slug) {
  if (!stateBase) return null;
  const rel = `reports/${slug}/runs`;
  const dir = path.join(stateBase, rel);
  if (!fs.existsSync(dir)) return null;
  const files = fs
    .readdirSync(dir, { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith(".md"))
    .map((entry) => entry.name)
    .sort();
  const latest = files.at(-1);
  if (!latest) return null;
  const reportPath = path.join(dir, latest);
  const body = fs.readFileSync(reportPath, "utf8");
  const match = body.match(/```json\n([\s\S]*?)\n```/);
  if (!match) return { path: reportPath, data: null, valid: false };
  try {
    const data = JSON.parse(match[1]);
    return { path: reportPath, data, valid: Boolean(data && typeof data === "object") };
  } catch {
    return { path: reportPath, data: null, valid: false };
  }
}

function dispatchMatchesCapability(state, expectedCapability) {
  const scheduleState = state?.scheduleState;
  const lastDecision = scheduleState && typeof scheduleState === "object" ? scheduleState.lastDecision : null;
  if (!lastDecision || typeof lastDecision !== "object") return { matched: false, reason: "no scheduler dispatch recorded" };
  if (lastDecision.kind !== "dispatch") return { matched: false, reason: `last decision was ${lastDecision.kind || "unknown"}` };
  const actual =
    (typeof lastDecision.capability === "string" && lastDecision.capability) ||
    (typeof lastDecision.executable === "string" && lastDecision.executable) ||
    (typeof lastDecision.action === "string" && lastDecision.action) ||
    "";
  if (actual !== expectedCapability) {
    return { matched: false, reason: `last dispatch was ${actual || "unknown"}` };
  }
  return { matched: true, reason: lastDecision.at || scheduleState.lastGoalTickAt || "dispatch recorded" };
}

function inspectLoopProof(activeGoals, stateBase, repo) {
  for (const item of activeGoals) {
    const slug = activeGoalSlug(item);
    if (!slug) continue;
    const template = readGoalTemplate(slug);
    const stateGoal = readStateGoal(stateBase, slug);
    const loopSource = isAgentLoop(stateGoal?.data) ? stateGoal.data : template;
    if (!isAgentLoop(loopSource)) continue;

    const capabilities = goalCapabilities(loopSource).length > 0 ? goalCapabilities(loopSource) : goalCapabilities(template);
    const expectedCapability = capabilities[0] || "";

    row("loops", `${slug} activation`, "active in config", "healthy", "kody.config.json", "consumer repo", "none");

    if (stateGoal) {
      row("loops", `${slug} materialized`, stateGoal.label, "healthy", stateGoal.path, "state repo", "none");
    } else {
      row("loops", `${slug} materialized`, "no runtime state found", "unknown", stateBase || "state checkout not provided", "state repo", "wait for scheduler or run loop");
    }

    if (stateGoal && expectedCapability) {
      const dispatch = dispatchMatchesCapability(stateGoal.data, expectedCapability);
      row(
        "loops",
        `${slug} scheduler`,
        dispatch.matched ? `dispatched ${expectedCapability}` : dispatch.reason,
        dispatch.matched ? "healthy" : "unknown",
        stateGoal.path,
        "state repo",
        dispatch.matched ? "none" : "prove scheduler fired this loop",
      );
    } else {
      row("loops", `${slug} scheduler`, "not proven", "unknown", stateGoal?.path || "no runtime state", "state repo", "prove scheduler fired this loop");
    }

    const report = expectedCapability ? latestReport(stateBase, expectedCapability) : null;
    const reportMatches =
      report?.valid === true &&
      report.data?.reportSlug === expectedCapability &&
      (typeof report.data?.repo !== "string" || report.data.repo === repo);
    if (reportMatches) {
      row("loops", `${slug} output`, `latest ${expectedCapability} report`, "healthy", report.path, "state repo", "none");
      const rows = Array.isArray(report.data.rows) ? report.data.rows : [];
      row(
        "loops",
        `${slug} outcome`,
        rows.length > 0 ? "report answers repo agency health" : "report has no rows",
        rows.length > 0 ? "healthy" : "unknown",
        report.path,
        "state repo",
        rows.length > 0 ? "none" : "fix report output contract",
      );
    } else if (report) {
      row("loops", `${slug} output`, "latest report does not match contract", "failing", report.path, "state repo", "fix report output contract");
      row("loops", `${slug} outcome`, "output does not prove goal outcome", "failing", report.path, "state repo", "fix report output contract");
    } else {
      row("loops", `${slug} output`, "no matching report found", "unknown", stateBase || "state checkout not provided", "state repo", "run the loop and verify report");
      row("loops", `${slug} outcome`, "no output to judge", "unknown", stateBase || "state checkout not provided", "state repo", "run the loop and verify report");
    }

    const profile = expectedCapability ? readCapabilityProfile(expectedCapability) : null;
    const outcome = String(template?.destination?.outcome || loopSource?.destination?.outcome || "");
    const intentFits =
      expectedCapability === reportSlug &&
      profile?.capabilityKind === "observe" &&
      /AI Agency/i.test(outcome) &&
      /current repo/i.test(outcome);
    row(
      "loops",
      `${slug} intent`,
      intentFits ? "observe-only repo agency health" : "intent not proven",
      intentFits ? "healthy" : "unknown",
      template ? `.kody/goals/templates/${slug}/state.json` : stateGoal?.path || "",
      intentFits ? "Store" : "operator",
      intentFits ? "none" : "confirm loop matches company intent",
    );
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
inspectLoopProof(activeGoals, stateBase, repo);
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
