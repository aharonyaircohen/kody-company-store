import assert from "node:assert/strict";
import { readFile, readdir } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import { describe, it } from "node:test";

const profileUrl = new URL(
  "../implementations/build-knowledge-graph/runtime.json",
  import.meta.url,
);
const scriptUrl = new URL(
  "../implementations/build-knowledge-graph/scripts/build-knowledge-graph.sh",
  import.meta.url,
);
const loopUrl = new URL(
  "../goals/templates/knowledge-system-refresh/state.json",
  import.meta.url,
);
const workflowUrl = new URL("../workflows/refresh-knowledge-system/workflow.json", import.meta.url);
const publishScriptUrl = new URL(
  "../implementations/publish-knowledge-system/scripts/publish-knowledge-system.sh",
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
      { shell: "scripts/build-knowledge-graph.sh", timeoutSec: 5400 },
      { script: "skipAgent" },
    ]);
    assert.match(script, /graphifyy==0\.9\.18/);
    assert.match(script, /pwd\)\/\.\.\/build-business-graph\.jq/);
    assert.match(script, /technical-graph\.json/);
    assert.match(script, /cp "\$BUSINESS_FILE" "\$ARTIFACT_DIR\/graph\.json"/);
    assert.doesNotMatch(script, /graphify cluster-only/);
    assert.doesNotMatch(script, /graph\.html/);
    assert.match(script, /--slurpfile code "\$BASE_GRAPH"/);
    assert.match(script, /\/api\/kody\/company\/backend\/export/);
    assert.doesNotMatch(script, /-X PUT[\s\S]*\/api\/kody\/knowledge-system/);
    assert.match(businessFilter, /agencyDefinitions/);
    assert.match(businessFilter, /agencyStates/);
    assert.match(businessFilter, /agencyOutputs/);
    assert.match(script, /GITHUB_REPOSITORY/);
    assert.match(script, /conversationEntries/);
    assert.match(script, /raw chat data is[\s\S]*intentionally excluded/i);
  });

  it("publishes the canonical visible graph without generated viewer HTML", async () => {
    const script = await readFile(publishScriptUrl, "utf8");

    assert.match(script, /graph\.json/);
    assert.doesNotMatch(script, /graph\.html/);
    assert.doesNotMatch(script, /htmlStorageId/);
    assert.doesNotMatch(script, /knowledge-visualization/);
  });

  it("connects purpose, execution, Runs, outputs, issues, and pull requests", async () => {
    const input = {
      repository: "acme/widgets",
      code: {
        nodes: [
          { source_file: "apps/dashboard/app/page.tsx" },
          { source_file: "packages/agency/src/index.ts" },
        ],
      },
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
            {
              kind: "implementation",
              recordId: "implementation-1",
              createdAt: "2026-07-23T00:00:00Z",
              data: {
                id: "deploy-with-kody",
                capabilityRef: { kind: "capability", id: "deploy" },
                agentRef: { kind: "agent", id: "kody" },
              },
            },
          ],
          agencyStates: [],
          agencyRuns: [
            {
              runId: "run-1",
              subjectId: "release",
              subjectType: "goal",
              run: {
                status: "succeeded",
                subjectId: "release",
                subjectType: "goal",
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
          repoDocs: [
            {
              kind: "context:architecture",
              doc: { title: "Architecture context" },
            },
            {
              kind: "todo:release",
              doc: { title: "Release checklist" },
            },
            {
              kind: "instructions",
              doc: [],
            },
            {
              kind: "secrets.enc",
              doc: { ciphertext: "hidden" },
            },
          ],
          agencyRecords: [
            {
              kind: "observation",
              recordId: "observation-old",
              updatedAt: "2026-07-22T00:00:00Z",
              doc: {
                id: "observation-old",
                capability: "deploy",
                subject: "release",
                summary: "Release used to be blocked",
              },
            },
            {
              kind: "observation",
              recordId: "observation-1",
              updatedAt: "2026-07-23T00:00:00Z",
              doc: {
                id: "observation-1",
                capability: "deploy",
                subject: "release",
                summary: "Release is blocked",
              },
            },
            {
              kind: "finding",
              recordId: "finding-1",
              doc: {
                id: "finding-1",
                title: "Release finding",
                observationIds: ["observation-1"],
                learningIds: ["learning-1"],
              },
            },
            {
              kind: "learning",
              recordId: "learning-1",
              doc: {
                id: "learning-1",
                summary: "Keep releases small",
                findingId: "finding-1",
              },
            },
          ],
          agents: [
            {
              slug: "kody",
              frontmatter: { name: "Kody" },
              body: "Developer agent",
            },
          ],
          intents: [{ intentId: "quality", intent: { for: "Duplicate" } }],
          catalog: [{ category: "capability", slug: "deploy", doc: {} }],
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
    const nodeIds = graph.nodes.map((node) => node.id);

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
      relations.includes(
        "kody:agency:capability:deploy|implemented-by|kody:agency:implementation:deploy-with-kody",
      ),
    );
    assert.ok(
      relations.includes(
        "kody:agency:implementation:deploy-with-kody|run-by|kody:agent:kody",
      ),
    );
    assert.ok(
      relations.includes(
        "kody:agency:goal:release|has-run|kody:run:run-1",
      ),
    );
    assert.ok(
      relations.includes("kody:run:run-1|produces|kody:output:output-1"),
    );
    assert.ok(
      relations.includes("github:issue:7|resolved-by|github:pr:8"),
    );
    assert.ok(nodeIds.includes("kody:repoDocs:context:architecture"));
    assert.ok(nodeIds.includes("kody:repoDocs:todo:release"));
    assert.ok(!nodeIds.includes("kody:repoDocs:secrets.enc"));
    assert.ok(!nodeIds.includes("kody:agencyRecords:observation-old"));
    assert.ok(!nodeIds.includes("kody:intents:quality"));
    assert.ok(!nodeIds.includes("kody:catalog:deploy"));
    assert.ok(nodeIds.includes("project:area:apps/dashboard"));
    assert.ok(nodeIds.includes("project:area:packages/agency"));
    assert.equal(
      graph.nodes.find(
        (node) => node.id === "project:area:apps/dashboard",
      )?.domain,
      "technical",
    );
    assert.equal(
      graph.nodes.find((node) => node.id === "kody:agencyRecords:finding-1")
        ?.domain,
      "knowledge",
    );
    assert.ok(
      relations.includes(
        "kody:agencyRecords:observation-1|evidence-for|kody:agencyRecords:finding-1",
      ),
    );
    assert.ok(
      relations.includes(
        "kody:agencyRecords:finding-1|produces-learning|kody:agencyRecords:learning-1",
      ),
    );
    assert.ok(
      relations.includes(
        "repo:acme/widgets|has-context|kody:repoDocs:context:architecture",
      ),
    );
    assert.ok(
      relations.includes(
        "repo:acme/widgets|tracks|kody:repoDocs:todo:release",
      ),
    );
    assert.equal(
      graph.edges.some(
        (edge) => edge.relation === "groups" || edge.relation === "contains",
      ),
      false,
    );
    assert.equal(
      graph.edges.some(
        (edge) =>
          edge.source === "repo:acme/widgets" &&
          edge.target === "github:issue:7" &&
          edge.relation === "tracks",
      ),
      true,
    );
    const connectedNodeIds = new Set(
      graph.edges.flatMap((edge) => [edge.source, edge.target]),
    );
    assert.equal(
      graph.nodes.every((node) => connectedNodeIds.has(node.id)),
      true,
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
});
