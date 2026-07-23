import { existsSync } from "node:fs";
import { readFile, readdir } from "node:fs/promises";
import { join, resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const implementationsRoot = join(root, "implementations");
const inventoryPath = join(
  root,
  "docs",
  "implementation-migration-inventory.json",
);

const inventory = JSON.parse(await readFile(inventoryPath, "utf8"));
const implementationIds = (
  await readdir(implementationsRoot, { withFileTypes: true })
)
  .filter(
    (entry) =>
      entry.isDirectory() &&
      existsSync(join(implementationsRoot, entry.name, "definition.json")),
  )
  .map((entry) => entry.name)
  .sort();

const explicitActions = new Map();

for (const id of inventory.classifications.addAtomicMethod) {
  explicitActions.set(id, { action: "add-atomic-method" });
}

for (const [id, replacement] of Object.entries(
  inventory.classifications.retireAlias,
)) {
  explicitActions.set(id, { action: "retire-alias", replacement });
}

for (const [classification, action] of [
  ["replaceWithUnifiedGraph", "replace-with-unified-graph"],
  ["moveToWorkflow", "move-to-workflow"],
  ["moveToTestFixture", "move-to-test-fixture"],
  ["moveToRuntimeService", "move-to-runtime-service"],
  ["retypeAsScript", "retype-as-script"],
]) {
  for (const id of inventory.classifications[classification]) {
    const existing = explicitActions.get(id);
    if (existing && existing.action !== "retype-as-script") {
      throw new Error(
        `Implementation "${id}" has conflicting actions "${existing.action}" and "${action}"`,
      );
    }
    explicitActions.set(id, { action });
  }
}

const removedActions = new Set([
  "retire-alias",
  "replace-with-unified-graph",
  "move-to-workflow",
  "move-to-test-fixture",
  "move-to-runtime-service",
]);
const missingRemovedIds = [...explicitActions.entries()]
  .filter(
    ([id, record]) =>
      removedActions.has(record.action) && !implementationIds.includes(id),
  )
  .map(([id]) => id);

if (
  implementationIds.length +
    missingRemovedIds.length -
    inventory.classifications.addAtomicMethod.length !==
  inventory.sourceTotal
) {
  throw new Error(
    `Inventory does not account for all ${inventory.sourceTotal} source Implementations`,
  );
}

const records = [
  ...implementationIds.map((id) => ({
    id,
    ...(explicitActions.get(id) ?? { action: inventory.defaultAction }),
    present: true,
  })),
  ...missingRemovedIds.map((id) => ({
    id,
    ...explicitActions.get(id),
    present: false,
  })),
].sort((left, right) => left.id.localeCompare(right.id));

const removed = records.filter((record) => removedActions.has(record.action));

console.log(
  JSON.stringify(
    {
      sourceTotal: inventory.sourceTotal,
      classifiedTotal: records.length,
      currentTotal: implementationIds.length,
      proposedRemovalTotal: removed.length,
      proposedRetainedTotal:
        inventory.sourceTotal -
        removed.length +
        inventory.classifications.addAtomicMethod.length,
      records,
    },
    null,
    2,
  ),
);
