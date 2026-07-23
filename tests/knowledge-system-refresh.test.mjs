import assert from "node:assert/strict";
import { readFile, readdir } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import { describe, it } from "node:test";

const profileUrl = new URL(
  "../implementations/build-knowledge-graph/runtime.json",
  import.meta.url,
);
const scriptUrl = new URL(
  "../implementations/build-knowledge-graph/build-knowledge-graph.sh",
  import.meta.url,
);
const loopUrl = new URL(
  "../goals/templates/knowledge-system-refresh/state.json",
  import.meta.url,
);
const workflowUrl = new URL("../workflows/refresh-knowledge-system/workflow.json", import.meta.url);
const publishScriptUrl = new URL(
  "../implementations/publish-knowledge-system/publish-knowledge-system.sh",
  import.meta.url,
);
const dispatchProfileUrl = new URL(
  "../implementations/dispatch-due-loops/runtime.json",
  import.meta.url,
);
const businessFilterUrl = new URL(
  "../implementations/build-knowledge-graph/build-business-graph.jq",
  import.meta.url,
);

describe("knowledge-system-refresh", () => {
  it("keeps graph identity only on the Knowledge System builder", async () => {
    const root = new URL("../implementations/", import.meta.url);
    const folders = await readdir(root);
    const names = await Promise.all(
      folders.map(async (folder) => {
        const raw = await readFile(new URL(`${folder}/definition.json`, root), "utf8");
        return JSON.parse(raw).id;
      }),
    );
    assert.deepEqual(names.filter((name) => name.includes("graph")), ["build-knowledge-graph"]);
  });

  it("builds repository-scoped artifacts without publishing them", async () => {
    const profile = JSON.parse(await readFile(profileUrl, "utf8"));
    const definition = JSON.parse(await readFile(new URL("../implementations/build-knowledge-graph/definition.json", import.meta.url), "utf8"));
    const script = await readFile(scriptUrl, "utf8");
    const businessFilter = await readFile(businessFilterUrl, "utf8");

    assert.equal(definition.id, "build-knowledge-graph");
    assert.deepEqual(profile.scripts.preflight, [
      { shell: "build-knowledge-graph.sh", timeoutSec: 5400 },
      { script: "skipAgent" },
    ]);
    assert.match(script, /graphifyy==0\.9\.18/);
    assert.match(script, /\/api\/kody\/company\/backend\/export/);
    assert.doesNotMatch(script, /-X PUT[\s\S]*\/api\/kody\/knowledge-system/);
    assert.match(businessFilter, /agencyDefinitions/);
    assert.match(businessFilter, /agencyStates/);
    assert.match(businessFilter, /agencyOutputs/);
    assert.match(script, /external-reference/);
    assert.match(script, /GITHUB_REPOSITORY/);
    assert.match(script, /conversationEntries/);
    assert.match(script, /raw chat data is[\s\S]*intentionally excluded/i);
  });

  it("connects purpose, execution, Runs, outputs, issues, and pull requests", async () => {
    const input = {
      repository: "acme/widgets",
      backend: {
        tables: {
          agencyDefinitions: [
            {
              kind: "intent",
              recordId: "intent-1",
              createdAt: "2026-07-23T00:00:00Z",
              data: { id: "quality", direction: "Stay reliable" },
            },
            {
              kind: "operation",
              recordId: "operation-1",
              createdAt: "2026-07-23T00:00:00Z",
              data: {
                id: "delivery",
                name: "Delivery",
                responsibility: "Ship",
                intentIds: ["quality"],
              },
            },
            {
              kind: "goal",
              recordId: "goal-1",
              createdAt: "2026-07-23T00:00:00Z",
              data: {
                id: "release",
                operationId: "delivery",
                objective: { desiredState: "Released" },
                executionRef: { kind: "workflow", id: "release-flow" },
              },
            },
            {
              kind: "workflow",
              recordId: "workflow-1",
              createdAt: "2026-07-23T00:00:00Z",
              data: {
                id: "release-flow",
                steps: [
                  {
                    id: "deploy",
                    capabilityRef: { kind: "capability", id: "deploy" },
                  },
                ],
              },
            },
            {
              kind: "capability",
              recordId: "capability-1",
              createdAt: "2026-07-23T00:00:00Z",
              data: { id: "deploy", action: "Deploy" },
            },
          ],
          agencyStates: [],
          agencyRuns: [
            {
              runId: "run-1",
              run: {
                status: "succeeded",
                trace: [
                  { kind: "goal", id: "release", revision: "goal-1" },
                ],
              },
            },
          ],
          agencyOutputs: [
            {
              recordId: "output-1",
              runId: "run-1",
              data: { key: "deployed", kind: "evidence" },
            },
          ],
        },
      },
      issues: [{ number: 7, title: "Release", state: "OPEN", url: "issue" }],
      prs: [
        {
          number: 8,
          title: "Ship",
          state: "OPEN",
          url: "pr",
          closingIssuesReferences: [{ number: 7 }],
        },
      ],
    };
    const result = spawnSync(
      "jq",
      ["-f", businessFilterUrl.pathname],
      { input: JSON.stringify(input), encoding: "utf8" },
    );
    assert.equal(result.status, 0, result.stderr);
    const graph = JSON.parse(result.stdout);
    const relations = graph.edges.map(
      (edge) => `${edge.source}|${edge.relation}|${edge.target}`,
    );

    assert.ok(
      relations.includes(
        "kody:agency:intent:quality|delegates|kody:agency:operation:delivery",
      ),
    );
    assert.ok(
      relations.includes(
        "kody:agency:goal:release|executes|kody:agency:workflow:release-flow",
      ),
    );
    assert.ok(
      relations.includes(
        "kody:agency:workflow:release-flow|uses|kody:agency:capability:deploy",
      ),
    );
    assert.ok(
      relations.includes("kody:run:run-1|produces|kody:output:output-1"),
    );
    assert.ok(
      relations.includes("github:issue:7|resolved-by|github:pr:8"),
    );
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
    assert.equal(workflow.startAt, undefined);
    assert.equal(workflow.steps.some((step) => "id" in step || "next" in step), false);
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
    const capability = JSON.parse(await readFile(new URL("../capabilities/dispatch-due-loops/definition.json", import.meta.url), "utf8"));

    assert.equal(capability.action, "dispatch-due-loops");
    assert.deepEqual(profile.inputs, [
      {
        name: "loop",
        flag: "--loop",
        type: "string",
        required: false,
        description: "Optional Loop id to force through the manual Trigger path.",
      },
    ]);
    assert.deepEqual(profile.scripts.preflight, [
      { script: "dispatchAgencyLoops" },
      { script: "skipAgent" },
    ]);
  });
});
