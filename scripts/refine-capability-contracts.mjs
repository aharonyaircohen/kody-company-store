import { createHash } from "node:crypto";
import { readFile, readdir, writeFile } from "node:fs/promises";
import { join, resolve } from "node:path";

const apply = process.argv.includes("--apply");
const root = resolve(import.meta.dirname, "..");
const capabilitiesRoot = join(root, "capabilities");
const implementationsRoot = join(root, "implementations");

function canonical(value) {
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
  if (value && typeof value === "object") {
    return `{${Object.entries(value)
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([key, item]) => `${JSON.stringify(key)}:${canonical(item)}`)
      .join(",")}}`;
  }
  return JSON.stringify(value);
}

function inputType(input) {
  if (Array.isArray(input?.choices) && input.choices.length > 0) {
    return { type: "string", enum: input.choices };
  }
  if (input?.type === "int" || input?.type === "number") return { type: "integer" };
  if (input?.type === "bool" || input?.type === "boolean") return { type: "boolean" };
  return { type: "string" };
}

function inputSchema(inputs) {
  const safeInputs = Array.isArray(inputs) ? inputs.filter((input) => input?.name) : [];
  return {
    type: "object",
    properties: Object.fromEntries(
      safeInputs.map((input) => [
        input.name,
        {
          ...inputType(input),
          ...(typeof input.describe === "string" && input.describe
            ? { description: input.describe }
            : {}),
        },
      ]),
    ),
    required: safeInputs.filter((input) => input.required).map((input) => input.name),
    additionalProperties: false,
  };
}

function outputSchema(outputContract) {
  const actions = Array.isArray(outputContract?.actionTypes)
    ? outputContract.actionTypes.filter((action) => typeof action === "string")
    : [];
  return {
    type: "object",
    properties: {
      ...(actions.length ? { action: { type: "string", enum: actions } } : {}),
      reason: { type: "string" },
      summary: { type: "string" },
      data: { type: "object", additionalProperties: true },
    },
    additionalProperties: true,
  };
}

function permissionNames(cliTools, fallback) {
  const values = Array.isArray(cliTools) ? cliTools : fallback;
  if (!Array.isArray(values)) return [];
  return [
    ...new Set(
      values
        .map((value) =>
          typeof value === "string"
            ? value
            : typeof value?.name === "string"
              ? value.name
              : "",
        )
        .map((value) => value.trim())
        .filter(Boolean),
    ),
  ];
}

const ids = (await readdir(capabilitiesRoot, { withFileTypes: true }))
  .filter((entry) => entry.isDirectory())
  .map((entry) => entry.name)
  .sort();

const inventory = [];
for (const id of ids) {
  const capabilityPath = join(capabilitiesRoot, id, "definition.json");
  const implementationPath = join(implementationsRoot, id, "definition.json");
  const runtimePath = join(implementationsRoot, id, "runtime.json");
  const [capability, implementation, runtime] = await Promise.all(
    [capabilityPath, implementationPath, runtimePath].map(async (path) =>
      JSON.parse(await readFile(path, "utf8")),
    ),
  );
  const refined = {
    ...capability,
    inputSchema: inputSchema(runtime.inputs),
    outputSchema: outputSchema(runtime.outputContract),
    effects: Array.isArray(runtime.writesTo) ? runtime.writesTo : capability.effects ?? [],
    permissions: permissionNames(runtime.cliTools, capability.permissions),
  };
  const refinedImplementation = {
    ...implementation,
    compatibleCapabilityRevision: createHash("sha256")
      .update(canonical(refined))
      .digest("hex"),
  };
  inventory.push({
    id,
    type: implementation.type,
    visibility: runtime.internal === true ? "internal" : "public",
  });
  if (apply) {
    await Promise.all([
      writeFile(capabilityPath, `${JSON.stringify(refined, null, 2)}\n`),
      writeFile(
        implementationPath,
        `${JSON.stringify(refinedImplementation, null, 2)}\n`,
      ),
    ]);
  }
}

const counts = inventory.reduce(
  (result, item) => {
    result[item.type] += 1;
    result[item.visibility] += 1;
    return result;
  },
  { agent: 0, script: 0, public: 0, internal: 0 },
);
console.log(
  JSON.stringify({ mode: apply ? "apply" : "dry-run", total: ids.length, counts, inventory }, null, 2),
);
