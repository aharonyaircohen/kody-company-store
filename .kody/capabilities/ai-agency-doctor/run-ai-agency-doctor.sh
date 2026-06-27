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

AI_AGENCY_DOCTOR_DRY_RUN="$DRY_RUN" node <<'NODE'
const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const dryRun = process.env.AI_AGENCY_DOCTOR_DRY_RUN === "1";
const reportSlug = "ai-agency-doctor";
const reportFile = `reports/${reportSlug}.md`;
const cwd = process.cwd();
const generatedAt = new Date().toISOString();

const findings = [];
const passed = [];

function exists(rel) {
  return fs.existsSync(path.join(cwd, rel));
}

function listDirs(rel) {
  const dir = path.join(cwd, rel);
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();
}

function listFiles(rel, suffix) {
  const dir = path.join(cwd, rel);
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir, { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith(suffix))
    .map((entry) => entry.name.slice(0, -suffix.length))
    .sort();
}

function readText(rel) {
  return fs.readFileSync(path.join(cwd, rel), "utf8");
}

function readJson(rel) {
  return JSON.parse(readText(rel));
}

function asList(value) {
  if (Array.isArray(value)) return value.filter((item) => typeof item === "string" && item.length > 0);
  if (typeof value === "string" && value.length > 0) return [value];
  return [];
}

function addFinding(severity, id, title, why, fix, owner, data = {}) {
  findings.push({ severity, id, title, why, fix, owner, data });
}

function addPassed(id, title) {
  passed.push({ id, title });
}

function parseProfile(slug) {
  const rel = `.kody/capabilities/${slug}/profile.json`;
  try {
    return { ok: true, profile: readJson(rel) };
  } catch (error) {
    addFinding(
      "red",
      `capability.${slug}.invalid-profile`,
      `Capability ${slug} has invalid profile.json`,
      "The capability cannot be loaded reliably.",
      "Fix profile.json so it is valid JSON.",
      "capability",
      { slug, error: String(error.message || error) },
    );
    return { ok: false, profile: null };
  }
}

let config = {};
let configOk = true;
if (exists("kody.config.json")) {
  try {
    config = readJson("kody.config.json");
    addPassed("config.valid-json", "kody.config.json is valid JSON");
  } catch (error) {
    configOk = false;
    addFinding(
      "red",
      "config.invalid-json",
      "kody.config.json is invalid JSON",
      "The agency cannot reliably resolve active agents, capabilities, or goals.",
      "Fix kody.config.json syntax.",
      "AI Agency setup",
      { error: String(error.message || error) },
    );
  }
} else {
  addFinding(
    "yellow",
    "config.missing",
    "kody.config.json is missing",
    "The Doctor cannot see active Store selections or state-repo settings.",
    "Add kody.config.json or run the Doctor from a configured Kody repo.",
    "AI Agency setup",
  );
}

const company = configOk && config && typeof config.company === "object" && config.company ? config.company : {};
const activeAgents = asList(company.activeAgents);
const activeCapabilities = asList(company.activeCapabilities ?? company.activeExecutables);
const activeGoals = asList(company.activeGoals);

const agents = new Set(listFiles(".kody/agents", ".md"));
const capabilities = new Set(listDirs(".kody/capabilities"));
const localGoalTemplates = new Set(listDirs(".kody/goals/templates"));
const localGoalInstances = new Set(listDirs(".kody/goals/instances"));
const commands = new Set(listFiles(".kody/commands", ".md"));
const contexts = new Set(listFiles(".kody/context", ".md"));

if (agents.size > 0) addPassed("agents.present", `${agents.size} local agent file(s) found`);
else addFinding("yellow", "agents.none-local", "No local agent files found", "The repo may depend entirely on Store agents.", "Confirm active agents resolve from the Store.", "AI Agency setup");

if (capabilities.size > 0) addPassed("capabilities.present", `${capabilities.size} local capability folder(s) found`);
else addFinding("yellow", "capabilities.none-local", "No local capability folders found", "The repo may depend entirely on Store capabilities.", "Confirm active capabilities resolve from the Store.", "AI Agency setup");

for (const slug of activeAgents) {
  if (agents.has(slug)) {
    addPassed(`active-agent.${slug}.local`, `Active agent ${slug} exists locally`);
  } else {
    addFinding(
      "yellow",
      `active-agent.${slug}.store-or-missing`,
      `Active agent ${slug} is not local`,
      "This is safe if the agent exists in the Store; broken if it exists nowhere.",
      "Confirm the Store contains this agent or add a local agent file.",
      "AI Agency setup",
      { slug },
    );
  }
}

for (const slug of activeCapabilities) {
  if (capabilities.has(slug)) {
    addPassed(`active-capability.${slug}.local`, `Active capability ${slug} exists locally`);
  } else {
    addFinding(
      "yellow",
      `active-capability.${slug}.store-or-missing`,
      `Active capability ${slug} is not local`,
      "This is safe if the capability exists in the Store; broken if it exists nowhere.",
      "Confirm the Store contains this capability or add a local capability folder.",
      "AI Agency setup",
      { slug },
    );
  }
}

for (const slug of activeGoals) {
  if (localGoalInstances.has(slug) || localGoalTemplates.has(slug)) {
    addPassed(`active-goal.${slug}.local`, `Active goal ${slug} exists locally`);
  } else {
    addFinding(
      "yellow",
      `active-goal.${slug}.store-or-missing`,
      `Active goal ${slug} is not local`,
      "This is safe if the goal template exists in the Store; broken if it exists nowhere.",
      "Confirm the Store contains this goal template or add a local goal instance/template.",
      "AI Agency setup",
      { slug },
    );
  }
}

for (const slug of capabilities) {
  const profileResult = parseProfile(slug);
  if (!profileResult.ok) continue;
  const profile = profileResult.profile;
  const name = typeof profile.name === "string" ? profile.name : "";
  if (name !== slug) {
    addFinding(
      "yellow",
      `capability.${slug}.name-mismatch`,
      `Capability folder ${slug} has profile name ${name || "(missing)"}`,
      "Slug/name drift makes activation and report links harder to understand.",
      "Make profile.json name match the folder slug.",
      "capability",
      { slug, name },
    );
  } else {
    addPassed(`capability.${slug}.name`, `Capability ${slug} profile name matches`);
  }

  const agent = typeof profile.agent === "string" ? profile.agent : "";
  if (!agent) {
    addFinding(
      "red",
      `capability.${slug}.missing-agent`,
      `Capability ${slug} has no agent`,
      "The engine has no identity to run this work as.",
      "Set profile.json agent to an active local or Store agent.",
      "capability",
      { slug },
    );
  } else if (agents.has(agent)) {
    addPassed(`capability.${slug}.agent`, `Capability ${slug} agent ${agent} exists locally`);
  } else {
    addFinding(
      "yellow",
      `capability.${slug}.agent-store-or-missing`,
      `Capability ${slug} uses non-local agent ${agent}`,
      "This is safe if the agent exists in the Store; broken if it exists nowhere.",
      "Confirm the Store contains this agent or add a local agent file.",
      "capability",
      { slug, agent },
    );
  }

  const preflight = Array.isArray(profile.scripts?.preflight) ? profile.scripts.preflight : [];
  for (const step of preflight) {
    if (!step || typeof step.shell !== "string") continue;
    const rel = `.kody/capabilities/${slug}/${step.shell}`;
    if (exists(rel)) {
      addPassed(`capability.${slug}.shell.${step.shell}`, `Capability ${slug} shell ${step.shell} exists`);
    } else {
      addFinding(
        "red",
        `capability.${slug}.missing-shell.${step.shell}`,
        `Capability ${slug} references missing shell ${step.shell}`,
        "The capability preflight will fail before any report is written.",
        `Add ${rel} or remove the shell step.`,
        "capability",
        { slug, shell: step.shell },
      );
    }
  }

  const readsFrom = asList(profile.readsFrom ?? profile.reads_from);
  for (const ref of readsFrom) {
    if (contexts.has(ref) || exists(`reports/${ref}.md`) || exists(`.kody/reports/${ref}.md`)) {
      addPassed(`capability.${slug}.reads.${ref}`, `Capability ${slug} reads ${ref}`);
    }
  }
}

for (const slug of localGoalTemplates) {
  let goal;
  try {
    goal = readJson(`.kody/goals/templates/${slug}/state.json`);
  } catch (error) {
    addFinding(
      "red",
      `goal-template.${slug}.invalid-json`,
      `Goal template ${slug} has invalid state.json`,
      "The goal cannot be activated reliably.",
      "Fix the goal template JSON.",
      "goal",
      { slug, error: String(error.message || error) },
    );
    continue;
  }

  if (goal.state !== "inactive") {
    addFinding(
      "yellow",
      `goal-template.${slug}.not-inactive`,
      `Goal template ${slug} is ${goal.state || "(missing state)"}`,
      "Store/local templates should start inactive; runtime instances become active.",
      "Set template state to inactive.",
      "goal",
      { slug, state: goal.state ?? null },
    );
  } else {
    addPassed(`goal-template.${slug}.inactive`, `Goal template ${slug} starts inactive`);
  }

  const goalCapabilities = asList(goal.capabilities);
  if (goalCapabilities.length > 10) {
    addFinding(
      "yellow",
      `goal-template.${slug}.wide-loop`,
      `Goal template ${slug} has ${goalCapabilities.length} capabilities`,
      "Wide loops are harder to reason about and slower to rotate through.",
      "Split the loop into lanes if the capabilities do not share one owner.",
      "goal",
      { slug, count: goalCapabilities.length },
    );
  }

  for (const capability of goalCapabilities) {
    if (capabilities.has(capability) || activeCapabilities.includes(capability)) {
      addPassed(`goal-template.${slug}.capability.${capability}`, `Goal template ${slug} references known capability ${capability}`);
    } else {
      addFinding(
        "yellow",
        `goal-template.${slug}.capability-store-or-missing.${capability}`,
        `Goal template ${slug} references non-local capability ${capability}`,
        "This is safe if the capability exists in the Store; broken if it exists nowhere.",
        "Confirm the Store contains this capability or add/activate it locally.",
        "goal",
        { slug, capability },
      );
    }
  }
}

for (const slug of agents) {
  const body = readText(`.kody/agents/${slug}.md`);
  if (/^every:\s*/m.test(body) || /^schedule:\s*/m.test(body) || /^capabilit(y|ies):\s*/m.test(body)) {
    addFinding(
      "yellow",
      `agent.${slug}.owns-work`,
      `Agent ${slug} appears to contain job or schedule fields`,
      "Agent files should describe identity, not work ownership.",
      "Move schedule, method, and output rules into a capability or loop.",
      "agent",
      { slug },
    );
  }
}

if (commands.size > 0) addPassed("commands.present", `${commands.size} command file(s) found`);

const red = findings.filter((finding) => finding.severity === "red").length;
const yellow = findings.filter((finding) => finding.severity === "yellow").length;
const status = red > 0 ? "Red" : yellow > 0 ? "Yellow" : "Green";

function escapeYaml(value) {
  return JSON.stringify(value);
}

function section(title, severity) {
  const items = findings.filter((finding) => finding.severity === severity);
  if (items.length === 0) return `## ${title}\n\nNone.\n`;
  return [
    `## ${title}`,
    "",
    ...items.flatMap((finding) => [
      `### ${severity === "red" ? "Red" : "Yellow"}: ${finding.title}`,
      "",
      `- Why it matters: ${finding.why}`,
      `- Fix: ${finding.fix}`,
      `- Owner: ${finding.owner}`,
      `- Id: \`${finding.id}\``,
      "",
    ]),
  ].join("\n");
}

const reportData = {
  schemaVersion: 1,
  generatedAt,
  status,
  counts: { red, yellow, passed: passed.length },
  findings,
  passed,
};

const frontmatter = [
  "---",
  `slug: ${reportSlug}`,
  `generatedAt: "${generatedAt}"`,
  `status: ${status.toLowerCase()}`,
  "counts:",
  `  red: ${red}`,
  `  yellow: ${yellow}`,
  `  passed: ${passed.length}`,
  "findings:",
  ...findings.map((finding) => `  - id: ${finding.id}\n    severity: ${finding.severity}\n    title: ${escapeYaml(finding.title)}`),
  "---",
  "",
].join("\n");

const report = `${frontmatter}# AI Agency Doctor

AI Agency Health: ${status}

| Signal | Count |
|---|---:|
| Broken | ${red} |
| Warnings | ${yellow} |
| Passed | ${passed.length} |

${section("Broken", "red")}
${section("Warnings", "yellow")}
## Passed Checks

${passed.length === 0 ? "None." : passed.map((item) => `- ${item.title}`).join("\n")}

## Machine Data

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

function normalizeRepo(value) {
  return String(value || "")
    .replace(/^https:\/\/github\.com\//, "")
    .replace(/\.git$/, "")
    .replace(/^\/+|\/+$/g, "");
}

function resolveStateTarget() {
  let repo = "";
  const view = runGh(["repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner"]);
  if (view.status === 0) repo = view.stdout.trim();
  if (!repo) throw new Error(view.stderr.trim() || "Could not resolve current repository with gh");

  const [owner, name] = repo.split("/");
  const stateRepo = normalizeRepo(config?.state?.repo || config?.stateRepo || `${owner}/kody-state`);
  const statePath = String(config?.state?.path || config?.statePath || name).replace(/^\/+|\/+$/g, "");
  return {
    stateRepo,
    reportPath: `${statePath ? `${statePath}/` : ""}${reportFile}`,
  };
}

function writeReport() {
  const { stateRepo, reportPath } = resolveStateTarget();
  const get = runGh(["api", `/repos/${stateRepo}/contents/${reportPath}`]);
  let sha = "";
  if (get.status === 0 && get.stdout.trim()) {
    try {
      sha = JSON.parse(get.stdout).sha || "";
    } catch {
      sha = "";
    }
  }

  const content = Buffer.from(report).toString("base64");
  const args = [
    "api",
    "-X",
    "PUT",
    `/repos/${stateRepo}/contents/${reportPath}`,
    "-f",
    "message=chore(reports): refresh ai-agency-doctor",
    "-f",
    `content=${content}`,
  ];
  if (sha) args.push("-f", `sha=${sha}`);

  const put = runGh(args);
  if (put.status !== 0) throw new Error(put.stderr.trim() || put.stdout.trim() || "Could not write report");
  return { stateRepo, reportPath };
}

if (dryRun) {
  process.stdout.write(`${report}\n`);
  process.stdout.write(`DONE\nCOMMIT_MSG: chore(reports): refresh ai-agency-doctor\nPR_SUMMARY:\n- Dry run only; no report write attempted.\n- AI Agency Health: ${status} (${red} broken, ${yellow} warnings, ${passed.length} passed).\n`);
} else {
  const target = writeReport();
  process.stdout.write(`DONE\nCOMMIT_MSG: chore(reports): refresh ai-agency-doctor\nPR_SUMMARY:\n- Refreshed ${target.reportPath} in ${target.stateRepo}.\n- AI Agency Health: ${status} (${red} broken, ${yellow} warnings, ${passed.length} passed).\n`);
}
NODE
