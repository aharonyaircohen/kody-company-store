import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";

const [command, id, value, ...rest] = process.argv.slice(2);
if (!command || !id) throw new Error("usage: agency-state.mjs <decide|deliver|resolve|correct-learning-observation> <finding-id> ...");

const config = JSON.parse(readFileSync("kody.config.json", "utf8"));
const owner = config.github?.owner;
const repo = config.github?.repo;
const stateSlug = String(config.state?.repo || `${owner}/kody-state`)
  .replace(/^https:\/\/github\.com\//, "")
  .replace(/\.git$/, "");
const [stateOwner, stateRepo] = stateSlug.split("/");
const statePath = String(config.state?.path || repo).replace(/^\/+|\/+$/g, "");
const stateBranch = config.state?.branch || "main";

function gh(args) {
  return execFileSync("gh", args, { encoding: "utf8" }).trim();
}

function apiPath(relative) {
  return `repos/${stateOwner}/${stateRepo}/contents/${statePath}/${relative}`;
}

function readJson(relative) {
  const payload = JSON.parse(gh([
    "api", "-H", "Accept: application/vnd.github+json", "--method", "GET",
    apiPath(relative), "-f", `ref=${stateBranch}`,
  ]));
  let text = Buffer.from(payload.content, "base64").toString("utf8");
  for (let depth = 0; depth < 3; depth += 1) {
    try {
      const parsed = JSON.parse(text);
      if (typeof parsed !== "string") return { value: parsed, sha: payload.sha };
      text = parsed;
    } catch {
      text = Buffer.from(text.replace(/\s/g, ""), "base64").toString("utf8");
    }
  }
  throw new Error(`invalid agency state: ${relative}`);
}

function writeJson(relative, data, message, sha = null) {
  const args = [
    "api", "-H", "Accept: application/vnd.github+json", "--method", "PUT",
    apiPath(relative), "-f", `message=${message}`, "-f", `branch=${stateBranch}`,
    "-f", `content=${Buffer.from(`${JSON.stringify(data, null, 2)}\n`).toString("base64")}`,
  ];
  if (sha) args.push("-f", `sha=${sha}`);
  gh(args);
}

const findingPath = `agency/findings/${id}.json`;
const current = readJson(findingPath);
const now = new Date().toISOString();

if (command === "decide") {
  current.value.phase = "deciding";
  current.value.decision = {
    action: value,
    reason: rest.join(" ") || `Use ${value}`,
    decidedAt: now,
  };
  current.value.updatedAt = now;
  writeJson(findingPath, current.value, `operate: decide ${id}`, current.sha);
} else if (command === "deliver") {
  current.value.status = "in_progress";
  current.value.phase = "verifying";
  current.value.deliveryRunId = value;
  current.value.updatedAt = now;
  writeJson(findingPath, current.value, `operate: deliver ${id}`, current.sha);
} else if (command === "resolve") {
  const observationIds = current.value.observationIds || [];
  const observationId = observationIds.includes(value)
    ? value
    : observationIds.at(-1);
  if (!observationId) throw new Error(`finding ${id} has no Observation to verify`);
  const learningId = `learning-${id}-${now.replace(/[^0-9]/g, "").toLowerCase()}`;
  const learning = {
    version: 1,
    id: learningId,
    findingId: id,
    observationId,
    changedModel: rest.shift() || "unknown",
    summary: rest.join(" ") || "Finding verified healthy",
    evidence: current.value.observationIds || [],
    learnedAt: now,
  };
  writeJson(`agency/learnings/${learningId}.json`, learning, `learn: ${id}`);
  current.value.status = "resolved";
  current.value.phase = "closed";
  current.value.learningIds = [...new Set([...(current.value.learningIds || []), learningId])];
  current.value.resolvedAt = now;
  current.value.updatedAt = now;
  writeJson(findingPath, current.value, `operate: resolve ${id}`, current.sha);
  console.log(learningId);
} else if (command === "correct-learning-observation") {
  const learningId = value;
  const observationId = rest[0];
  if (!(current.value.observationIds || []).includes(observationId)) {
    throw new Error(`Observation ${observationId} is not linked to finding ${id}`);
  }
  const learningPath = `agency/learnings/${learningId}.json`;
  const learning = readJson(learningPath);
  learning.value.observationId = observationId;
  writeJson(learningPath, learning.value, `learn: correct Observation for ${id}`, learning.sha);
} else {
  throw new Error(`unknown command: ${command}`);
}
