import assert from "node:assert/strict";
import { readFile, readdir } from "node:fs/promises";
import { describe, it } from "node:test";

const profileUrl = new URL(
  "../capabilities/build-knowledge-graph/profile.json",
  import.meta.url,
);
const scriptUrl = new URL(
  "../capabilities/build-knowledge-graph/build-knowledge-graph.sh",
  import.meta.url,
);
const loopUrl = new URL(
  "../goals/templates/knowledge-system-refresh/state.json",
  import.meta.url,
);
const workflowUrl = new URL("../workflows/refresh-knowledge-system/workflow.json", import.meta.url);
const publishScriptUrl = new URL(
  "../capabilities/publish-knowledge-system/publish-knowledge-system.sh",
  import.meta.url,
);
const dispatchProfileUrl = new URL(
  "../capabilities/dispatch-due-loops/profile.json",
  import.meta.url,
);

describe("knowledge-system-refresh", () => {
  it("keeps graph identity only on the Knowledge System builder", async () => {
    const root = new URL("../capabilities/", import.meta.url);
    const folders = await readdir(root);
    const names = await Promise.all(
      folders.map(async (folder) => {
        const raw = await readFile(new URL(`${folder}/profile.json`, root), "utf8");
        return JSON.parse(raw).name;
      }),
    );
    assert.deepEqual(names.filter((name) => name.includes("graph")), ["build-knowledge-graph"]);
  });

  it("builds repository-scoped artifacts without publishing them", async () => {
    const profile = JSON.parse(await readFile(profileUrl, "utf8"));
    const script = await readFile(scriptUrl, "utf8");

    assert.equal(profile.name, "build-knowledge-graph");
    assert.deepEqual(profile.scripts.preflight, [
      { shell: "build-knowledge-graph.sh", timeoutSec: 5400 },
      { script: "skipAgent" },
    ]);
    assert.match(script, /graphifyy/);
    assert.match(script, /\/api\/kody\/company\/backend\/export/);
    assert.doesNotMatch(script, /-X PUT[\s\S]*\/api\/kody\/knowledge-system/);
    assert.match(script, /agencyDefinitions/);
    assert.match(script, /agencyStates/);
    assert.match(script, /agencyOutputs/);
    assert.match(script, /GITHUB_REPOSITORY/);
    assert.match(script, /conversationEntries/);
    assert.match(script, /raw chat data is[\s\S]*intentionally excluded/i);
  });

  it("keeps business purpose in a Workflow and Loop", async () => {
    const loop = JSON.parse(await readFile(loopUrl, "utf8"));
    const workflow = JSON.parse(await readFile(workflowUrl, "utf8"));

    assert.equal(loop.state, "inactive");
    assert.equal(loop.type, "agentLoop");
    assert.equal(loop.schedule, "1d");
    assert.deepEqual(loop.loopTarget, { type: "workflow", id: "refresh-knowledge-system" });
    assert.deepEqual(workflow.steps.map((step) => step.capability), [
      "build-knowledge-graph",
      "create-knowledge-report",
      "publish-knowledge-system",
    ]);
  });

  it("publishes structured evidence for the owning Goal", async () => {
    const script = await readFile(publishScriptUrl, "utf8");

    assert.match(script, /KODY_CAPABILITY_RESULT/);
    assert.match(script, /graph-published/);
    assert.match(script, /knowledge-graph/);
    assert.match(script, /knowledge-report/);
    assert.match(script, /KODY_OUTPUT/);
  });

  it("uses the same generic Loop dispatcher for manual proof", async () => {
    const profile = JSON.parse(await readFile(dispatchProfileUrl, "utf8"));

    assert.equal(profile.action, "dispatch-due-loops");
    assert.deepEqual(profile.scripts.preflight, [
      { script: "dispatchAgencyLoops" },
      { script: "skipAgent" },
    ]);
  });
});
