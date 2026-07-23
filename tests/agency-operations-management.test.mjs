import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { describe, it } from "node:test";

describe("agency operations runtime state resolution", () => {
  it("keeps Operation runtime reads in the configured external state repo", async () => {
    const skill = await readFile(
      new URL(
        "../implementations/agency-operations-management/skills/agency-operations-management/SKILL.md",
        import.meta.url,
      ),
      "utf8",
    );

    assert.match(skill, /state\.repo/);
    assert.match(skill, /state\.path/);
    assert.match(skill, /state\.branch/);
    assert.match(skill, /<consumer-owner>\/kody-state/);
    assert.match(skill, /path `<consumer-repo>`/);
    assert.match(skill, /branch `main`/);
    assert.match(
      skill,
      /repos\/<state-owner>\/<state-repo>\/contents\/<state\.path>\/operations\/<operationId>\/operation\.json\?ref=<state\.branch>/,
    );
    assert.match(skill, /not the state target/i);
    assert.match(skill, /Do not fall back to the consumer repo or Store/i);
    assert.match(skill, /<state\.path>\/todos\/<id>\.json/);
    assert.match(skill, /managedModel: agentGoal/);
    assert.match(skill, /managedModel: agentLoop/);
    assert.match(skill, /Do not search legacy `goals\/<id>` or `loops\/<id>` paths/);
  });
});
