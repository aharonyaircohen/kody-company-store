import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { existsSync } from "node:fs";
import { readFile, readdir } from "node:fs/promises";
import { join } from "node:path";
import { describe, it } from "node:test";

const root = new URL("../", import.meta.url).pathname;
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
    assert.equal(implementations.length, capabilities.length);
    const types = new Set();

    for (const { name: id } of capabilities) {
      const capabilityDir = join(capabilitiesRoot, id);
      const implementationDir = join(implementationsRoot, id);
      const capability = JSON.parse(
        await readFile(join(capabilityDir, "definition.json"), "utf8"),
      );
      const implementation = JSON.parse(
        await readFile(join(implementationDir, "definition.json"), "utf8"),
      );
      const runtime = JSON.parse(
        await readFile(join(implementationDir, "runtime.json"), "utf8"),
      );

      assert.equal(existsSync(join(capabilityDir, "capability.md")), true);
      assert.equal(existsSync(join(capabilityDir, "profile.json")), false);
      assert.equal(existsSync(join(capabilityDir, "prompt.md")), false);
      assert.equal(capability.id, id);
      assert.equal(typeof capability.inputSchema, "object");
      assert.equal(typeof capability.outputSchema, "object");
      assert.deepEqual(implementation.capabilityRef, {
        kind: "capability",
        id,
      });
      assert.equal(
        implementation.compatibleCapabilityRevision,
        createHash("sha256").update(canonical(capability)).digest("hex"),
      );
      assert.equal(capability.inputSchema.additionalProperties, false);
      assert.equal(Array.isArray(capability.effects), true);
      assert.equal(Array.isArray(capability.permissions), true);
      types.add(implementation.type);
      assert.equal(runtime.adapter, "kody-engine-profile");
      assert.equal(Object.hasOwn(runtime, "implementations"), false);
      if (implementation.type === "script") {
        assert.equal(existsSync(join(implementationDir, "prompt.md")), false);
      } else {
        assert.equal(implementation.agentRef.kind, "agent");
      }
    }
    assert.deepEqual(types, new Set(["agent", "script"]));
  });
});
