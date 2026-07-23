import { readFile, readdir } from "node:fs/promises";
import { join, resolve } from "node:path";

import { validateImplementationCatalog } from "./lib/implementation-validation.mjs";

if (process.argv.includes("--apply")) {
  throw new Error(
    "Implementation validation is read-only. Capability contracts must be edited at their own boundary.",
  );
}

const root = resolve(import.meta.dirname, "..");
const capabilitiesRoot = join(root, "capabilities");
const implementationsRoot = join(root, "implementations");

async function directories(path) {
  return (await readdir(path, { withFileTypes: true }))
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();
}

async function readJson(path) {
  return JSON.parse(await readFile(path, "utf8"));
}

const capabilities = new Map(
  await Promise.all(
    (await directories(capabilitiesRoot)).map(async (id) => [
      id,
      await readJson(join(capabilitiesRoot, id, "definition.json")),
    ]),
  ),
);

const implementations = await Promise.all(
  (await directories(implementationsRoot)).map(async (id) => {
    const implementationRoot = join(implementationsRoot, id);
    const files = await readdir(implementationRoot);
    return {
      id,
      definition: await readJson(
        join(implementationRoot, "definition.json"),
      ),
      runtime: files.includes("runtime.json")
        ? await readJson(join(implementationRoot, "runtime.json"))
        : null,
      files,
    };
  }),
);

const errors = validateImplementationCatalog({
  capabilities,
  implementations,
});
if (errors.length > 0) {
  throw new Error(
    `Implementation catalog is invalid:\n- ${errors.join("\n- ")}`,
  );
}

const counts = implementations.reduce(
  (result, implementation) => {
    result[implementation.definition.type] += 1;
    result[
      implementation.runtime?.internal === true ? "internal" : "public"
    ] += 1;
    return result;
  },
  { agent: 0, script: 0, public: 0, internal: 0 },
);

console.log(
  JSON.stringify(
    {
      mode: "read-only",
      capabilities: capabilities.size,
      implementations: implementations.length,
      counts,
    },
    null,
    2,
  ),
);
