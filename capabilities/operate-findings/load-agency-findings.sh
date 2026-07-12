#!/usr/bin/env bash
set -euo pipefail

node --input-type=module <<'NODE'
import { execFileSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  writeFileSync,
} from "node:fs";
import { join } from "node:path";

const config = JSON.parse(readFileSync("kody.config.json", "utf8"));
const owner = config.github?.owner;
const repo = config.github?.repo;
if (!owner || !repo) {
  throw new Error("kody.config.json must define github.owner and github.repo");
}
const stateSlug = String(config.state?.repo || `${owner}/kody-state`)
  .replace(/^https:\/\/github\.com\//, "")
  .replace(/\.git$/, "");
const [stateOwner, stateRepo] = stateSlug.split("/");
if (!stateOwner || !stateRepo) throw new Error("state.repo must be owner/repo");
const statePath = String(config.state?.path || repo).replace(/^\/+|\/+$/g, "");
const stateBranch = config.state?.branch || "main";
const localRoot = process.env.KODY_STATE_ROOT;

function gh(args) {
  return execFileSync("gh", args, { encoding: "utf8" }).trim();
}

function remoteJson(relative) {
  const apiPath = `repos/${stateOwner}/${stateRepo}/contents/${statePath}/${relative}`;
  const payload = JSON.parse(
    gh(["api", "--method", "GET", apiPath, "-f", `ref=${stateBranch}`]),
  );
  return JSON.parse(Buffer.from(payload.content, "base64").toString("utf8"));
}

let records = [];
if (localRoot) {
  const dir = join(localRoot, statePath, "agency", "findings");
  if (existsSync(dir)) {
    records = readdirSync(dir)
      .filter((name) => name.endsWith(".json"))
      .map((name) => JSON.parse(readFileSync(join(dir, name), "utf8")));
  }
} else {
  const dirPath = `repos/${stateOwner}/${stateRepo}/contents/${statePath}/agency/findings`;
  try {
    const entries = JSON.parse(
      gh(["api", "--method", "GET", dirPath, "-f", `ref=${stateBranch}`]),
    );
    records = entries
      .filter((entry) => entry.type === "file" && entry.name.endsWith(".json"))
      .map((entry) => remoteJson(`agency/findings/${entry.name}`));
  } catch (error) {
    const text = error instanceof Error ? error.message : String(error);
    if (!/404|Not Found/i.test(text)) throw error;
  }
}

const findings = records.filter(
  (finding) => finding?.status === "open" || finding?.status === "in_progress",
);
const output = {
  version: 1,
  repo: `${owner}/${repo}`,
  stateRepo: `${stateOwner}/${stateRepo}`,
  statePath,
  stateBranch,
  loadedAt: new Date().toISOString(),
  findings,
};
mkdirSync(".kody-engine", { recursive: true });
writeFileSync(
  ".kody-engine/agency-findings.json",
  `${JSON.stringify(output, null, 2)}\n`,
);
console.log(`AGENCY_FINDINGS_LOADED count=${findings.length} state=${stateSlug}/${statePath}@${stateBranch}`);
NODE
