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
    agent: "kody",
    schedule: "1d",
  },
  {
    loop: "agency-operations-loop",
    capability: "agency-operations-management",
    agent: "kody",
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

  it("keeps portfolio design and runtime operation separated", async () => {
    const company = await readFile(
      new URL("../capabilities/company-portfolio-management/capability.md", import.meta.url),
      "utf8",
    );
    const portfolio = await readFile(
      new URL("../capabilities/agency-portfolio-management/capability.md", import.meta.url),
      "utf8",
    );
    const operations = await readFile(
      new URL("../capabilities/agency-operations-management/capability.md", import.meta.url),
      "utf8",
    );

    assert.match(company, /priorities/i);
    assert.match(company, /ceo-performance-review/i);
    assert.match(portfolio, /operations, goals, loops, capabilities, workflows, and agents/i);
    assert.match(portfolio, /proposed/i);
    assert.match(portfolio, /provisioning/i);
    assert.match(portfolio, /active/i);
    assert.match(operations, /activate, pause, resume, retry, or escalate/i);
    assert.match(operations, /ai-agency-health/i);
  });

  it("makes Operation the portfolio manager's required scaling boundary", async () => {
    const profile = JSON.parse(
      await readFile(
        new URL("../capabilities/agency-portfolio-management/profile.json", import.meta.url),
        "utf8",
      ),
    );
    const skill = await readFile(
      new URL(
        "../capabilities/agency-portfolio-management/skills/agency-portfolio-management/SKILL.md",
        import.meta.url,
      ),
      "utf8",
    );

    assert.equal(profile.agent, "kody");
    assert.match(skill, /Intent owns why/i);
    assert.match(skill, /Operation owns.*responsibility/i);
    assert.match(skill, /operations\/<id>\/operation\.json/);
    assert.match(skill, /responsibility/);
    assert.match(skill, /doesNotOwn/);
    assert.match(skill, /intentIds/);
    assert.match(skill, /Goals and Loops/i);
    assert.match(skill, /proposed.*provisioning.*active/is);
    assert.match(skill, /operation-creator/i);
    assert.match(skill, /traceable.*request/i);
    assert.doesNotMatch(skill, /draft the minimum `operations\/<id>\/operation\.json` contract/i);
  });

  it("constrains runtime work to one active Operation contract", async () => {
    const profile = JSON.parse(
      await readFile(
        new URL("../capabilities/agency-operations-management/profile.json", import.meta.url),
        "utf8",
      ),
    );
    const body = await readFile(
      new URL("../capabilities/agency-operations-management/capability.md", import.meta.url),
      "utf8",
    );
    const skill = await readFile(
      new URL(
        "../capabilities/agency-operations-management/skills/agency-operations-management/SKILL.md",
        import.meta.url,
      ),
      "utf8",
    );

    assert.equal(profile.agent, "kody");
    assert.match(`${body}\n${skill}`, /operations\/<operationId>\/operation\.json/);
    assert.match(`${body}\n${skill}`, /status.*active/i);
    assert.match(`${body}\n${skill}`, /only.*Goals.*Loops/i);
    assert.match(`${body}\n${skill}`, /doesNotOwn/);
    assert.match(`${body}\n${skill}`, /refuse/i);
    assert.doesNotMatch(`${body}\n${skill}`, /COO owns|CTO owns|CEO owns/);
  });

  it("gives portfolio managers a verifiable state-repo persistence contract", async () => {
    const company = await readFile(
      new URL(
        "../capabilities/company-portfolio-management/skills/company-portfolio-management/SKILL.md",
        import.meta.url,
      ),
      "utf8",
    );
    const agency = await readFile(
      new URL(
        "../capabilities/agency-portfolio-management/skills/agency-portfolio-management/SKILL.md",
        import.meta.url,
      ),
      "utf8",
    );

    assert.match(company, /portfolio\.json/);
    assert.match(agency, /agency-portfolio\.json/);
    assert.doesNotMatch(agency, /Approved Operation contracts live at/);
    for (const skill of [company, agency]) {
      assert.match(skill, /gh api --method PUT/);
      assert.match(skill, /read it back/i);
      assert.match(skill, /FAILED/);
      assert.match(skill, /Do not clone the state repo/i);
      assert.match(skill, /A roll-forward is not a new decision/i);
      assert.match(skill, /do not PUT/i);
    }
  });
});
