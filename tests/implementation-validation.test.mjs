import assert from "node:assert/strict";
import { describe, it } from "node:test";

import {
  capabilityRevision,
  validateImplementationCatalog,
} from "../scripts/lib/implementation-validation.mjs";

const capability = {
  id: "inspect-repository",
  action: "inspect repository",
  purpose: "Return repository facts.",
  inputSchema: { type: "object" },
  outputSchema: { type: "object" },
  effects: [],
  permissions: [],
  success: "Facts returned.",
  failure: "Inspection failed.",
};

function implementation(id, overrides = {}) {
  return {
    id,
    definition: {
      id,
      capabilityRef: { kind: "capability", id: capability.id },
      compatibleCapabilityRevision: capabilityRevision(capability),
      type: "agent",
      agentRef: { kind: "agent", id: "kody" },
      ...overrides.definition,
    },
    runtime: {
      claudeCode: { skills: [], tools: ["Read"] },
      capabilityTools: [],
      scripts: { preflight: [], postflight: [] },
      ...overrides.runtime,
    },
    files: overrides.files ?? ["definition.json", "runtime.json"],
  };
}

describe("validateImplementationCatalog", () => {
  it("allows several technical methods for one Capability", () => {
    const errors = validateImplementationCatalog({
      capabilities: new Map([[capability.id, capability]]),
      implementations: [
        implementation("inspect-with-agent"),
        implementation("inspect-with-tool"),
      ],
    });

    assert.deepEqual(errors, []);
  });

  it("rejects an agent label when the method has no agent execution assets", () => {
    const errors = validateImplementationCatalog({
      capabilities: new Map([[capability.id, capability]]),
      implementations: [
        implementation("inspect-script", {
          runtime: {
            claudeCode: { skills: [], tools: [] },
            capabilityTools: [],
            scripts: {
              preflight: [{ script: "inspectFlow" }],
              postflight: [],
            },
          },
        }),
      ],
    });

    assert.match(errors.join("\n"), /has no prompt, Skill, or agent tool/);
  });

  it("rejects prompts and Agent references on script methods", () => {
    const errors = validateImplementationCatalog({
      capabilities: new Map([[capability.id, capability]]),
      implementations: [
        implementation("inspect-script", {
          definition: { type: "script" },
          files: ["definition.json", "runtime.json", "prompt.md"],
        }),
      ],
    });

    assert.match(errors.join("\n"), /script.*must not define agentRef/);
    assert.match(errors.join("\n"), /script.*must not contain prompt.md/);
  });

  it("rejects missing Capabilities and stale compatible revisions", () => {
    const missing = implementation("missing-capability", {
      definition: {
        capabilityRef: { kind: "capability", id: "not-installed" },
      },
    });
    const stale = implementation("stale-method", {
      definition: { compatibleCapabilityRevision: "stale" },
    });

    const errors = validateImplementationCatalog({
      capabilities: new Map([[capability.id, capability]]),
      implementations: [missing, stale],
    });

    assert.match(errors.join("\n"), /references missing Capability/);
    assert.match(errors.join("\n"), /compatibleCapabilityRevision is stale/);
  });
});
