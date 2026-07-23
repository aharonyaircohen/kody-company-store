set -euo pipefail

node --input-type=module <<'NODE'
import { execFileSync, spawnSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";

const config = JSON.parse(readFileSync("kody.config.json", "utf8"));
const owner = config.github?.owner;
const repo = config.github?.repo;
if (!owner || !repo) {
  throw new Error("kody.config.json must define github.owner and github.repo");
}

const quality = config.quality && typeof config.quality === "object" ? config.quality : {};
const configuredChecks = ["typecheck", "lint", "testUnit"]
  .filter((name) => typeof quality[name] === "string" && quality[name].trim())
  .map((name) => ({ name, command: quality[name].trim() }));
if (configuredChecks.length === 0) {
  throw new Error("kody.config.json must define at least one quality command");
}

const context = process.env.KODY_SOURCE_HEALTH_CONTEXT || "Kody Source Health";
const sha = process.env.KODY_SOURCE_HEALTH_SHA || execFileSync("git", ["rev-parse", "HEAD"], { encoding: "utf8" }).trim();
const repoSlug = `${owner}/${repo}`;

function gh(args) {
  return execFileSync("gh", args, { encoding: "utf8" }).trim();
}

function statusUrl() {
  const runId = process.env.GITHUB_RUN_ID?.trim();
  if (!runId) return "";
  const server = process.env.GITHUB_SERVER_URL || "https://github.com";
  const repository = process.env.GITHUB_REPOSITORY || repoSlug;
  return `${server}/${repository}/actions/runs/${runId}`;
}

function publish(state, description) {
  const args = [
    "api",
    "--method",
    "POST",
    `repos/${repoSlug}/statuses/${sha}`,
    "-f",
    `state=${state}`,
    "-f",
    `context=${context}`,
    "-f",
    `description=${description.slice(0, 140)}`,
  ];
  const targetUrl = statusUrl();
  if (targetUrl) args.push("-f", `target_url=${targetUrl}`);
  gh(args);
}

if (process.env.KODY_SOURCE_HEALTH_FORCE !== "1") {
  const combined = JSON.parse(gh(["api", `repos/${repoSlug}/commits/${sha}/status`]) || "{}");
  const existing = (Array.isArray(combined.statuses) ? combined.statuses : [])
    .find((status) => status?.context === context && ["success", "failure"].includes(status?.state));
  if (existing) {
    console.log(`REPO_SOURCE_HEALTH status=${existing.state} skipped=already-checked sha=${sha}`);
    process.exit(0);
  }
}

publish("pending", `Running ${configuredChecks.length} configured source checks`);

function run(command) {
  console.log(`SOURCE_HEALTH_RUN ${command}`);
  const result = spawnSync(command, {
    shell: true,
    stdio: "inherit",
    env: process.env,
  });
  if (result.error) throw result.error;
  return result.status ?? 1;
}

if (process.env.KODY_SOURCE_HEALTH_SKIP_INSTALL !== "1") {
  let installCommand = "";
  if (existsSync("pnpm-lock.yaml")) {
    execFileSync("corepack", ["enable"], { stdio: "inherit" });
    installCommand = "corepack pnpm install --frozen-lockfile";
  } else if (existsSync("yarn.lock")) {
    execFileSync("corepack", ["enable"], { stdio: "inherit" });
    installCommand = "corepack yarn install --immutable";
  } else if (existsSync("package-lock.json")) {
    installCommand = "npm ci";
  } else if (existsSync("bun.lock") || existsSync("bun.lockb")) {
    installCommand = "bun install --frozen-lockfile";
  }

  if (installCommand && run(installCommand) !== 0) {
    publish("error", "Dependency installation failed");
    console.log(`REPO_SOURCE_HEALTH status=error failed=dependency-install sha=${sha}`);
    process.exit(0);
  }
}

const failed = [];
for (const check of configuredChecks) {
  if (run(check.command) !== 0) failed.push(check.name);
}

if (failed.length > 0) {
  publish("failure", `Failed: ${failed.join(", ")}`);
  console.log(`REPO_SOURCE_HEALTH status=failure failed=${failed.join(",")} sha=${sha}`);
} else {
  publish("success", `Passed ${configuredChecks.length} configured source checks`);
  console.log(`REPO_SOURCE_HEALTH status=success checks=${configuredChecks.length} sha=${sha}`);
}
NODE
