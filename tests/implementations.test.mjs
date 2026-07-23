import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { existsSync } from "node:fs";
import { readFile, readdir } from "node:fs/promises";
import { join } from "node:path";
import { describe, it } from "node:test";

const root = new URL("../", import.meta.url).pathname;
const capabilitiesRoot = join(root, "capabilities");
const implementationsRoot = join(root, "implementations");

const retiredAliases = new Set([
  "ci-health",
  "kody-analyzer",
  "kody-mem",
  "kody-operator",
  "kody-vibe",
  "memory-compaction",
]);

const legacyGraphImplementations = new Set([
  "analyze-agency-structure",
  "analyze-ci-health",
  "analyze-dependencies",
  "analyze-documentation",
  "analyze-pull-requests",
]);

const workflowOwnedMethods = new Set([
  "cleanup",
  "code-health",
  "docs-health",
  "quality-watch",
]);

const testOnlyImplementations = new Set([
  "job-live-verify",
  "plan-verify",
  "probe-skill",
  "task-job-fail-once",
]);

const runtimeServices = new Set([
  "capability-scheduler",
  "capability-tick",
  "capability-tick-scripted",
  "dispatch-due-loops",
  "goal-manager",
  "goal-scheduler",
  "task-jobs",
]);

const deterministicScriptImplementations = new Set([
  "auto-fix-ci",
  "auto-resolve",
  "auto-sync",
  "ci-check",
  "job-gap-scan",
  "preview-health",
  "redispatch",
  "revert",
  "task-memory-extractor",
]);

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

describe("Capability and Implementation separation", () => {
  it("declares both asset roots", async () => {
    const manifest = JSON.parse(
      await readFile(join(root, "kody-store.json"), "utf8"),
    );
    assert.equal(manifest.assetRoots.capabilities, "capabilities");
    assert.equal(manifest.assetRoots.implementations, "implementations");
  });

  it("keeps contracts in capabilities and runtime assets in implementations", async () => {
    const capabilities = (
      await readdir(capabilitiesRoot, { withFileTypes: true })
    ).filter((entry) => entry.isDirectory());
    const implementations = (
      await readdir(implementationsRoot, { withFileTypes: true })
    ).filter((entry) => entry.isDirectory());
    const capabilityDefinitions = new Map();
    const types = new Set();

    for (const { name: id } of capabilities) {
      const capabilityDir = join(capabilitiesRoot, id);
      const capability = JSON.parse(
        await readFile(join(capabilityDir, "definition.json"), "utf8"),
      );

      assert.equal(existsSync(join(capabilityDir, "capability.md")), true);
      assert.equal(existsSync(join(capabilityDir, "profile.json")), false);
      assert.equal(existsSync(join(capabilityDir, "prompt.md")), false);
      assert.equal(capability.id, id);
      assert.equal(typeof capability.inputSchema, "object");
      assert.equal(typeof capability.outputSchema, "object");
      assert.equal(capability.inputSchema.additionalProperties, false);
      assert.equal(Array.isArray(capability.effects), true);
      assert.equal(Array.isArray(capability.permissions), true);
      assert.equal(
        capability.permissions.every(
          (permission) =>
            typeof permission === "string" && permission.trim().length > 0,
        ),
        true,
      );
      capabilityDefinitions.set(id, capability);
    }

    const implementedCapabilities = new Set();
    for (const { name: id } of implementations) {
      const implementationDir = join(implementationsRoot, id);
      const implementation = JSON.parse(
        await readFile(join(implementationDir, "definition.json"), "utf8"),
      );
      const runtime = JSON.parse(
        await readFile(join(implementationDir, "runtime.json"), "utf8"),
      );
      const capability = capabilityDefinitions.get(
        implementation.capabilityRef?.id,
      );

      assert.equal(implementation.id, id);
      assert.equal(implementation.capabilityRef?.kind, "capability");
      assert.ok(
        capability,
        `${id} must reference an existing Capability`,
      );
      assert.equal(
        implementation.compatibleCapabilityRevision,
        createHash("sha256").update(canonical(capability)).digest("hex"),
      );
      implementedCapabilities.add(implementation.capabilityRef.id);
      types.add(implementation.type);
      assert.equal(runtime.adapter, "kody-engine-profile");
      assert.equal(Object.hasOwn(runtime, "implementations"), false);
      if (implementation.type === "script") {
        assert.equal(existsSync(join(implementationDir, "prompt.md")), false);
      } else {
        assert.equal(implementation.agentRef.kind, "agent");
      }
    }

    assert.deepEqual(
      [...capabilityDefinitions.keys()].filter(
        (id) => !implementedCapabilities.has(id),
      ),
      [],
      "every Capability must have at least one available Implementation",
    );
    assert.deepEqual(types, new Set(["agent", "script"]));
  });

  it("keeps task-specific executables inside each Implementation scripts directory", async () => {
    const implementations = (
      await readdir(implementationsRoot, { withFileTypes: true })
    ).filter((entry) => entry.isDirectory());

    for (const { name: id } of implementations) {
      const implementationDir = join(implementationsRoot, id);
      const rootFiles = (
        await readdir(implementationDir, { withFileTypes: true })
      ).filter(
        (entry) =>
          entry.isFile() &&
          /\.(?:sh|py|js|mjs|ts)$/.test(entry.name),
      );
      assert.deepEqual(
        rootFiles.map((entry) => entry.name),
        [],
        `${id} must keep executables under scripts/`,
      );

      const runtime = JSON.parse(
        await readFile(join(implementationDir, "runtime.json"), "utf8"),
      );
      for (const phase of ["preflight", "postflight"]) {
        for (const step of runtime.scripts?.[phase] ?? []) {
          for (const shell of [step.shell, step.with?.shell]) {
            if (typeof shell !== "string") continue;
            assert.equal(
              shell.startsWith("scripts/"),
              true,
              `${id} must use a scripts/ path for ${shell}`,
            );
            assert.equal(
              existsSync(join(implementationDir, shell)),
              true,
              `${id} declares missing executable ${shell}`,
            );
          }
        }
      }
    }
  });

  it("keeps only complete technical methods in the production catalog", async () => {
    const implementationIds = new Set(
      (
        await readdir(implementationsRoot, { withFileTypes: true })
      )
        .filter((entry) => entry.isDirectory())
        .map((entry) => entry.name),
    );

    for (const id of [
      ...retiredAliases,
      ...legacyGraphImplementations,
      ...workflowOwnedMethods,
      ...testOnlyImplementations,
      ...runtimeServices,
    ]) {
      assert.equal(
        implementationIds.has(id),
        false,
        `${id} must not be a production Implementation`,
      );
    }
  });

  it("models deterministic technical methods as script implementations", async () => {
    for (const id of deterministicScriptImplementations) {
      const definition = JSON.parse(
        await readFile(
          join(implementationsRoot, id, "definition.json"),
          "utf8",
        ),
      );
      assert.equal(definition.type, "script", `${id} must be a script`);
      assert.equal(
        Object.hasOwn(definition, "agentRef"),
        false,
        `${id} must not select an Agent`,
      );
      assert.equal(
        existsSync(join(implementationsRoot, id, "prompt.md")),
        false,
        `${id} must not contain a prompt`,
      );
    }
  });

  it("does not duplicate identical local Skill assets", async () => {
    const implementations = (
      await readdir(implementationsRoot, { withFileTypes: true })
    ).filter((entry) => entry.isDirectory());
    const hashes = new Map();

    for (const { name: implementationId } of implementations) {
      const skillsRoot = join(implementationsRoot, implementationId, "skills");
      if (!existsSync(skillsRoot)) continue;
      const skills = (
        await readdir(skillsRoot, { withFileTypes: true })
      ).filter((entry) => entry.isDirectory());
      for (const { name: skillId } of skills) {
        const hash = await directoryHash(join(skillsRoot, skillId));
        const owner = hashes.get(hash);
        assert.equal(
          owner,
          undefined,
          `${implementationId}/${skillId} duplicates ${owner}`,
        );
        hashes.set(hash, `${implementationId}/${skillId}`);
      }
    }
  });
});

async function directoryHash(directory) {
  const entries = [];

  async function visit(current, relative = "") {
    const children = await readdir(current, { withFileTypes: true });
    children.sort((left, right) => left.name.localeCompare(right.name));
    for (const child of children) {
      const path = join(current, child.name);
      const relativePath = join(relative, child.name);
      if (child.isDirectory()) {
        await visit(path, relativePath);
      } else if (child.isFile()) {
        entries.push(
          `${relativePath}\0${await readFile(path, "base64")}`,
        );
      }
    }
  }

  await visit(directory);
  return createHash("sha256").update(entries.join("\0")).digest("hex");
}
