import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { describe, it } from "node:test";

const managementPairs = [
  {
    loop: "company-growth-loop",
    capability: "company-portfolio-management",
    agent: "ceo",
    schedule: "1w",
  },
  {
    loop: "agency-evolution-loop",
    capability: "agency-portfolio-management",
    agent: "cto",
    schedule: "1d",
  },
  {
    loop: "agency-operations-loop",
    capability: "agency-operations-management",
    agent: "coo",
    schedule: "1h",
  },
];

describe("Executive agency management", () => {
  it("replaces the legacy agency architect assets", () => {
    assert.equal(
      existsSync(new URL("../capabilities/agency-architect/", import.meta.url)),
      false,
    );
    assert.equal(
      existsSync(new URL("../goals/templates/agency-architect-loop/", import.meta.url)),
      false,
    );
  });

  for (const pair of managementPairs) {
    it(`ships ${pair.loop} -> ${pair.capability} -> ${pair.agent}`, async () => {
      const loopPath = new URL(`../goals/templates/${pair.loop}/state.json`, import.meta.url);
      const profilePath = new URL(`../capabilities/${pair.capability}/profile.json`, import.meta.url);
      const bodyPath = new URL(`../capabilities/${pair.capability}/capability.md`, import.meta.url);
      const skillPath = new URL(
        `../capabilities/${pair.capability}/skills/${pair.capability}/SKILL.md`,
        import.meta.url,
      );

      assert.equal(existsSync(loopPath), true, `${pair.loop} template must exist`);
      assert.equal(existsSync(profilePath), true, `${pair.capability} profile must exist`);
      assert.equal(existsSync(bodyPath), true, `${pair.capability} body must exist`);
      assert.equal(existsSync(skillPath), true, `${pair.capability} skill must exist`);

      const loop = JSON.parse(await readFile(loopPath, "utf8"));
      const profile = JSON.parse(await readFile(profilePath, "utf8"));
      const body = await readFile(bodyPath, "utf8");
      const skill = await readFile(skillPath, "utf8");

      assert.equal(loop.scheduleMode, "agentLoop");
      assert.equal(loop.schedule, pair.schedule);
      assert.deepEqual(loop.capabilities, [pair.capability]);
      assert.equal(profile.agent, pair.agent);
      assert.equal(profile.name, pair.capability);
      assert.equal(profile.action, pair.capability);
      assert.ok(profile.claudeCode.skills.includes(pair.capability));
      assert.match(`${body}\n${skill}`, /active company intents/i);
      assert.match(`${body}\n${skill}`, /intentId/);
    });
  }

  it("keeps executive authority separated", async () => {
    const ceo = await readFile(
      new URL("../capabilities/company-portfolio-management/capability.md", import.meta.url),
      "utf8",
    );
    const cto = await readFile(
      new URL("../capabilities/agency-portfolio-management/capability.md", import.meta.url),
      "utf8",
    );
    const coo = await readFile(
      new URL("../capabilities/agency-operations-management/capability.md", import.meta.url),
      "utf8",
    );

    assert.match(ceo, /priorities/i);
    assert.match(ceo, /ceo-performance-review/i);
    assert.match(cto, /goals, loops, capabilities, workflows, and agents/i);
    assert.match(coo, /activate, pause, resume, retry, or escalate/i);
    assert.match(coo, /ai-agency-health/i);
  });

  it("gives CEO and CTO a verifiable state-repo persistence contract", async () => {
    const ceo = await readFile(
      new URL(
        "../capabilities/company-portfolio-management/skills/company-portfolio-management/SKILL.md",
        import.meta.url,
      ),
      "utf8",
    );
    const cto = await readFile(
      new URL(
        "../capabilities/agency-portfolio-management/skills/agency-portfolio-management/SKILL.md",
        import.meta.url,
      ),
      "utf8",
    );

    assert.match(ceo, /portfolio\.json/);
    assert.match(cto, /agency-portfolio\.json/);
    for (const skill of [ceo, cto]) {
      assert.match(skill, /gh api --method PUT/);
      assert.match(skill, /read it back/i);
      assert.match(skill, /FAILED/);
      assert.match(skill, /Do not clone the state repo/i);
    }
  });
});
