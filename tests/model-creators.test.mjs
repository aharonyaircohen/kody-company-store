import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { describe, it } from "node:test";

const capabilitiesDir = new URL("../capabilities/", import.meta.url);

const creators = [
  {
    slug: "agent-creator",
    owns: ["identity", "judgment", "boundaries"],
    excludes: ["tasks", "schedules", "tools"],
  },
  {
    slug: "capability-creator",
    owns: ["ability", "inputs", "outputs", "skills", "scripts", "implementation"],
    excludes: ["goal progress", "loop cadence", "workflow order"],
  },
  {
    slug: "goal-creator",
    owns: ["outcome", "evidence", "completion rules"],
    excludes: ["capability implementation", "loop cadence", "agent identity"],
  },
  {
    slug: "loop-creator",
    owns: ["cadence", "wake target", "cursor", "deduplication"],
    excludes: ["business completion", "goal evidence", "workflow order"],
  },
  {
    slug: "workflow-creator",
    owns: ["ordered capability calls", "handoffs", "failure rules"],
    excludes: ["long-term progress", "schedule", "goal completion"],
  },
];

describe("agency-owned model creators", () => {
  it("ships one detailed Store capability per agency model", async () => {
    for (const creator of creators) {
      const dir = join(capabilitiesDir.pathname, creator.slug);
      assert.equal(existsSync(dir), true, `${creator.slug} must live in the Store`);

      const profile = JSON.parse(await readFile(join(dir, "profile.json"), "utf8"));
      const body = await readFile(join(dir, "capability.md"), "utf8");
      const prompt = await readFile(join(dir, "prompt.md"), "utf8");

      assert.equal(profile.action, creator.slug);
      assert.equal(profile.name, creator.slug);
      assert.equal(profile.role, "primitive");
      assert.equal(profile.kind, "oneshot");
      assert.deepEqual(profile.inputs, [
        {
          name: "issue",
          flag: "--issue",
          type: "int",
          required: true,
          describe: "GitHub issue number containing the focused model creation request.",
        },
      ]);
      assert.deepEqual(
        profile.scripts.postflight.map((step) => step.script),
        ["parseAgentResult", "validateAgencyModelProposal", "openAgencyModelReviewPr"],
      );
      assert.equal(
        profile.scripts.postflight.find((step) => step.script === "validateAgencyModelProposal")?.with?.modelKind,
        creator.slug === "agent-creator"
          ? "agent"
          : creator.slug === "loop-creator"
            ? "agentLoop"
            : creator.slug.replace("-creator", ""),
      );
      assert.deepEqual(profile.claudeCode.tools, ["Read", "Grep", "Glob"]);

      assert.match(prompt, /inspect the current agency/i);
      assert.match(prompt, /reuse existing/i);
      assert.match(prompt, /validate/i);
      assert.match(prompt, /PR_SUMMARY/);
      assert.match(body, /## Contract/);
      assert.match(body, /## Boundary/);

      for (const term of creator.owns) {
        assert.equal(
          `${body}\n${prompt}`.toLowerCase().includes(term.toLowerCase()),
          true,
          `${creator.slug} must explain ownership of ${term}`,
        );
      }
      for (const term of creator.excludes) {
        assert.equal(
          `${body}\n${prompt}`.toLowerCase().includes(term.toLowerCase()),
          true,
          `${creator.slug} must exclude ${term}`,
        );
      }
    }
  });

  it("does not keep a central agent factory", () => {
    assert.equal(existsSync(new URL("../capabilities/agent-factory/profile.json", import.meta.url)), false);
  });
});
