import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { describe, it } from "node:test";

const profileUrl = new URL(
  "../capabilities/knowledge-system-refresh/profile.json",
  import.meta.url,
);
const scriptUrl = new URL(
  "../capabilities/knowledge-system-refresh/refresh-knowledge-system.sh",
  import.meta.url,
);
const loopUrl = new URL(
  "../goals/templates/knowledge-system-refresh/state.json",
  import.meta.url,
);

describe("knowledge-system-refresh", () => {
  it("is a mechanical shared capability that publishes repository-scoped artifacts", async () => {
    const profile = JSON.parse(await readFile(profileUrl, "utf8"));
    const script = await readFile(scriptUrl, "utf8");

    assert.equal(profile.name, "knowledge-system-refresh");
    assert.deepEqual(profile.scripts.preflight, [
      { shell: "refresh-knowledge-system.sh", timeoutSec: 5400 },
      { script: "skipAgent" },
    ]);
    assert.match(script, /graphifyy/);
    assert.match(script, /\/api\/kody\/company\/backend\/export/);
    assert.match(script, /\/api\/kody\/knowledge-system/);
    assert.match(script, /GITHUB_REPOSITORY/);
    assert.match(script, /conversationEntries/);
    assert.match(script, /raw chat data is[\s\S]*intentionally excluded/i);
  });

  it("ships as an inactive loop that consumers can schedule", async () => {
    const loop = JSON.parse(await readFile(loopUrl, "utf8"));

    assert.equal(loop.state, "inactive");
    assert.equal(loop.type, "agentLoop");
    assert.equal(loop.schedule, "1d");
    assert.deepEqual(loop.capabilities, ["knowledge-system-refresh"]);
  });
});
