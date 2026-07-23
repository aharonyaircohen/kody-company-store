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
const stateSlug = String(config.state?.repo || `${owner}/kody-state`).replace(/^https:\/\/github\.com\//, "").replace(/\.git$/, "");
const [stateOwner, stateRepo] = stateSlug.split("/");
const statePath = String(config.state?.path || repo).replace(/^\/+|\/+$/g, "");
const stateBranch = config.state?.branch || "main";
const localRoot = process.env.KODY_STATE_ROOT;
const activeCapabilitySlugs = Array.isArray(config.company?.activeCapabilities)
  ? config.company.activeCapabilities.filter((value) => typeof value === "string")
  : [];

function capabilityProfile(slug) {
  const candidates = [
    join(process.cwd(), ".kody", "capabilities", slug, "profile.json"),
    join(process.env.KODY_STORE_CAPABILITIES_ROOT || "", slug, "profile.json"),
  ];
  const file = candidates.find((candidate) => candidate && existsSync(candidate));
  if (!file) return { name: slug, describe: "Active Capability", capabilityKind: null };
  const profile = JSON.parse(readFileSync(file, "utf8"));
  return {
    name: slug,
    describe: profile.describe || "Active Capability",
    capabilityKind: profile.capabilityKind || null,
    inputs: Array.isArray(profile.inputs) ? profile.inputs : [],
    tools: profile.capabilityTools || profile.tools || [],
  };
}

function gh(args) {
  return execFileSync("gh", args, { encoding: "utf8" }).trim();
}

function decodeContent(raw) {
  let text = raw;
  for (let depth = 0; depth < 4; depth += 1) {
    try {
      const parsed = JSON.parse(text);
      if (parsed && typeof parsed === "object" && typeof parsed.content === "string") {
        text = Buffer.from(parsed.content, "base64").toString("utf8");
        continue;
      }
      if (typeof parsed === "string") {
        text = parsed;
        continue;
      }
      return text;
    } catch {
      return text;
    }
  }
  return text;
}

function parseFindingReport(markdown, reportSlug, reportRunId) {
  const reportType = markdown.match(/^reportType:\s*([^\s]+)\s*$/m)?.[1];
  if (reportType !== "finding") return null;
  const json = markdown.match(/## Report data\s*\n```json\s*\n([\s\S]*?)\n```/)?.[1];
  if (!json) return null;
  try {
    const data = JSON.parse(json);
    if (!data.finding || typeof data.finding !== "object") return null;
    return { ...data.finding, reportSlug, reportRunId };
  } catch {
    return null;
  }
}

function localFindings() {
  const reportsDir = join(localRoot, statePath, "reports");
  if (!existsSync(reportsDir)) return [];
  return readdirSync(reportsDir)
    .flatMap((slug) => {
      const runsDir = join(reportsDir, slug, "runs");
      if (!existsSync(runsDir)) return [];
      const latest = readdirSync(runsDir).filter((name) => name.endsWith(".md")).sort().at(-1);
      if (!latest) return [];
      const finding = parseFindingReport(readFileSync(join(runsDir, latest), "utf8"), slug, latest.slice(0, -3));
      return finding ? [finding] : [];
    });
}

function remoteFindings() {
  const reportsPath = `repos/${stateOwner}/${stateRepo}/contents/${statePath}/reports`;
  let families = [];
  try {
    families = JSON.parse(gh(["api", "--method", "GET", reportsPath, "-f", `ref=${stateBranch}`]));
  } catch (error) {
    if (/404|Not Found/i.test(error instanceof Error ? error.message : String(error))) return [];
    throw error;
  }
  return families.filter((entry) => entry.type === "dir").flatMap((entry) => {
    const runsPath = `${reportsPath}/${entry.name}/runs`;
    let runs = [];
    try {
      runs = JSON.parse(gh(["api", "--method", "GET", runsPath, "-f", `ref=${stateBranch}`]));
    } catch {
      return [];
    }
    const latest = runs.filter((run) => run.type === "file" && run.name.endsWith(".md")).sort((a, b) => a.name.localeCompare(b.name)).at(-1);
    if (!latest) return [];
    const raw = gh(["api", "--method", "GET", `${runsPath}/${latest.name}`, "-f", `ref=${stateBranch}`]);
    const finding = parseFindingReport(decodeContent(raw), entry.name, latest.name.slice(0, -3));
    return finding ? [finding] : [];
  });
}

const findings = localRoot ? localFindings() : remoteFindings();
const output = {
  version: 1,
  repo: `${owner}/${repo}`,
  stateRepo: `${stateOwner}/${stateRepo}`,
  statePath,
  stateBranch,
  loadedAt: new Date().toISOString(),
  availableCapabilities: activeCapabilitySlugs.map(capabilityProfile),
  activeGoals: Array.isArray(config.company?.activeGoals) ? config.company.activeGoals : [],
  findings,
};
mkdirSync(".kody-engine", { recursive: true });
writeFileSync(".kody-engine/agency-findings.json", `${JSON.stringify(output, null, 2)}\n`);
console.log(`AGENCY_FINDING_REPORTS_LOADED count=${findings.length} state=${stateSlug}/${statePath}@${stateBranch}`);
NODE
