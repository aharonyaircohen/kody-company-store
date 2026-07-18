import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { mkdtemp, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, it } from "node:test";

const observerGoalPath = new URL("../goals/templates/agency-observer/state.json", import.meta.url);
const operatingGoalPath = new URL("../goals/templates/agency-operating-loop/state.json", import.meta.url);
const observerProfilePath = new URL("../capabilities/observe-repo-ci/profile.json", import.meta.url);
const sourceHealthProfilePath = new URL("../capabilities/repo-source-health/profile.json", import.meta.url);
const sourceHealthScriptPath = new URL("../capabilities/repo-source-health/run-repo-source-health.sh", import.meta.url);
const observerWorkflowPath = new URL("../workflows/agency-observer/workflow.json", import.meta.url);
const operatingWorkflowPath = new URL("../workflows/agency-operating-loop/workflow.json", import.meta.url);
const operatingProfilePath = new URL("../capabilities/operate-findings/profile.json", import.meta.url);
const operatingPromptPath = new URL("../capabilities/operate-findings/prompt.md", import.meta.url);
const operatingLoaderPath = new URL("../capabilities/operate-findings/load-agency-findings.sh", import.meta.url);
const observerScriptPath = new URL("../capabilities/observe-repo-ci/run-observe-repo-ci.sh", import.meta.url);
const agencyFlowProfilePath = new URL("../capabilities/observe-agency-flow/profile.json", import.meta.url);
const agencyFlowScriptPath = new URL("../capabilities/observe-agency-flow/run-observe-agency-flow.sh", import.meta.url);

function capabilityResult(stdout) {
  const line = stdout.split("\n").find((item) => item.startsWith("KODY_CAPABILITY_RESULT="));
  return line ? JSON.parse(line.slice("KODY_CAPABILITY_RESULT=".length)) : null;
}

function reportMarkdown({ type = "finding", title = "Default branch CI is failing", data }) {
  return [
    "---",
    'generatedAt: "2026-07-14T12:00:00.000Z"',
    `reportType: ${type}`,
    "reportTypeVersion: 1",
    "producer:",
    "  model: agency-observer",
    "  capability: observe-repo-ci",
    "---",
    `# ${title}`,
    "",
    "## Report data",
    "```json",
    JSON.stringify(data, null, 2),
    "```",
    "",
  ].join("\n");
}

describe("agency observer and operating loops", () => {
  it("keeps reports owned by workflows, not capabilities", async () => {
    const observer = JSON.parse(await readFile(observerGoalPath, "utf8"));
    const operating = JSON.parse(await readFile(operatingGoalPath, "utf8"));
    const sourceHealthCapability = JSON.parse(await readFile(sourceHealthProfilePath, "utf8"));
    const observeCapability = JSON.parse(await readFile(observerProfilePath, "utf8"));
    const operateCapability = JSON.parse(await readFile(operatingProfilePath, "utf8"));
    const operatePrompt = await readFile(operatingPromptPath, "utf8");
    const observerWorkflow = JSON.parse(await readFile(observerWorkflowPath, "utf8"));
    const operatingWorkflow = JSON.parse(await readFile(operatingWorkflowPath, "utf8"));

    assert.deepEqual(observer.loopTarget, { type: "workflow", id: "agency-observer" });
    assert.deepEqual(operating.loopTarget, { type: "workflow", id: "agency-operating-loop" });
    assert.deepEqual(observer.capabilities, []);
    assert.deepEqual(operating.capabilities, []);
    assert.deepEqual(observerWorkflow.steps.map((step) => step.capability), [
      "repo-source-health",
      "observe-repo-ci",
      "observe-agency-flow",
    ]);
    assert.deepEqual(observerWorkflow.steps[1].report, {
      type: "finding",
      version: 1,
      owner: "agency-observer",
      slugFact: "finding.id",
      titleFact: "finding.title",
      publishWhenFact: "finding.id",
      reviewStatus: "action-needed",
      reviewArea: "repo-health",
    });
    assert.deepEqual(operatingWorkflow.steps[0].report, {
      type: "learning",
      version: 1,
      owner: "agency-operating-loop",
      slugFact: "learning.id",
      titleFact: "learning.summary",
      publishWhenFact: "learning.id",
      reviewStatus: "info",
      reviewArea: "agency-learning",
    });
    assert.deepEqual(observerWorkflow.steps[2].report, {
      type: "finding",
      version: 1,
      owner: "agency-observer",
      slugFact: "finding.id",
      titleFact: "finding.title",
      publishWhenFact: "finding.id",
      reviewStatus: "action-needed",
      reviewArea: "agency-flow",
    });
    const agencyFlowCapability = JSON.parse(await readFile(agencyFlowProfilePath, "utf8"));
    assert.equal(agencyFlowCapability.capabilityKind, "observe");
    assert.deepEqual(agencyFlowCapability.writesTo, ["observations"]);
    assert.deepEqual(agencyFlowCapability.scripts.postflight, [{ script: "publishReport" }]);
    assert.equal(sourceHealthCapability.capabilityKind, "observe");
    assert.deepEqual(observeCapability.writesTo, ["observations"]);
    assert.deepEqual(observeCapability.scripts.postflight, [{ script: "publishReport" }]);
    assert.equal(operateCapability.claudeCode.enableSubmitTool, true);
    assert.deepEqual(
      operateCapability.scripts.postflight.map((step) => step.script),
      ["parseJobStateFromAgentResult", "writeJobStateFile", "publishReport", "appendCompanyActivity"],
    );
    assert.deepEqual(operateCapability.readsFrom, ["reports", "intents", "goals"]);
    assert.deepEqual(operateCapability.writesTo, ["capability-state"]);
    assert.match(operatePrompt, /\{\{jobStateJson\}\}/);
  });

  it("publishes configured source-check failure without failing the observer workflow", async () => {
    const cwd = await mkdtemp(join(tmpdir(), "kody-repo-source-health-"));
    try {
      const bin = join(cwd, "bin");
      const ghLog = join(cwd, "gh.log");
      mkdirSync(bin, { recursive: true });
      writeFileSync(join(cwd, "kody.config.json"), `${JSON.stringify({
        github: { owner: "A-Guy", repo: "example" },
        quality: {
          typecheck: 'node -e "process.exit(0)"',
          lint: 'node -e "process.exit(7)"',
          testUnit: 'node -e "process.exit(0)"',
        },
      })}\n`);
      const gh = join(bin, "gh");
      writeFileSync(gh, `#!/usr/bin/env bash\nprintf '%s\\n' "$*" >> "$GH_LOG"\nif [[ "$*" == *"/commits/"*"/status"* ]]; then printf '%s' '{"statuses":[]}'; else printf '%s' '{}'; fi\n`);
      chmodSync(gh, 0o755);

      const result = spawnSync("bash", [sourceHealthScriptPath.pathname], {
        cwd,
        env: { ...process.env, PATH: `${bin}:${process.env.PATH}`, GH_LOG: ghLog, KODY_SOURCE_HEALTH_SHA: "abc123", KODY_SOURCE_HEALTH_SKIP_INSTALL: "1" },
        encoding: "utf8",
      });

      assert.equal(result.status, 0, result.stderr);
      assert.match(result.stdout, /REPO_SOURCE_HEALTH status=failure/);
      assert.match(await readFile(ghLog, "utf8"), /-f context=Kody Source Health/);
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }
  });

  it("returns observation facts and lets the workflow publish the Finding report", async () => {
    const cwd = await mkdtemp(join(tmpdir(), "kody-agency-observer-"));
    const stateRoot = join(cwd, "state-root");
    try {
      mkdirSync(stateRoot, { recursive: true });
      writeFileSync(join(cwd, "kody.config.json"), `${JSON.stringify({
        github: { owner: "A-Guy", repo: "example" },
        state: { path: "example" },
      })}\n`);
      const result = spawnSync("bash", [observerScriptPath.pathname], {
        cwd,
        env: { ...process.env, KODY_STATE_ROOT: stateRoot, KODY_OBSERVER_CI_STATUS: "unhealthy", KODY_OBSERVER_NOW: "2026-07-14T12:00:00.000Z" },
        encoding: "utf8",
      });

      assert.equal(result.status, 0, result.stderr);
      const output = capabilityResult(result.stdout);
      assert.equal(output.status, "fail");
      assert.equal(output.facts.finding.id, "finding-repo-ci-main");
      assert.equal(output.facts.finding.status, "open");
      const observation = JSON.parse(await readFile(join(stateRoot, "example", "agency", "observations", "obs-ci-main-20260714t120000000z.json"), "utf8"));
      assert.equal(observation.status, "unhealthy");
      await assert.rejects(readFile(join(stateRoot, "example", "agency", "findings", "finding-repo-ci-main.json"), "utf8"), { code: "ENOENT" });
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }
  });

  it("does not create a Finding result for first-time healthy evidence", async () => {
    const cwd = await mkdtemp(join(tmpdir(), "kody-agency-observer-healthy-"));
    const stateRoot = join(cwd, "state-root");
    try {
      mkdirSync(stateRoot, { recursive: true });
      writeFileSync(join(cwd, "kody.config.json"), `${JSON.stringify({ github: { owner: "A-Guy", repo: "example" }, state: { path: "example" } })}\n`);
      const result = spawnSync("bash", [observerScriptPath.pathname], {
        cwd,
        env: { ...process.env, KODY_STATE_ROOT: stateRoot, KODY_OBSERVER_CI_STATUS: "healthy", KODY_OBSERVER_NOW: "2026-07-14T12:00:00.000Z" },
        encoding: "utf8",
      });
      assert.equal(result.status, 0, result.stderr);
      assert.equal(capabilityResult(result.stdout).facts.finding, undefined);
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }
  });

  it("returns a healthy update when a Finding report already exists", async () => {
    const cwd = await mkdtemp(join(tmpdir(), "kody-agency-observer-recovery-"));
    const stateRoot = join(cwd, "state-root");
    try {
      const runDir = join(stateRoot, "example", "reports", "finding-repo-ci-main", "runs");
      mkdirSync(runDir, { recursive: true });
      writeFileSync(join(runDir, "2026-07-14T11-45-00Z.md"), reportMarkdown({ data: { finding: { id: "finding-repo-ci-main", status: "open" } } }));
      writeFileSync(join(cwd, "kody.config.json"), `${JSON.stringify({ github: { owner: "A-Guy", repo: "example" }, state: { path: "example" } })}\n`);
      const result = spawnSync("bash", [observerScriptPath.pathname], {
        cwd,
        env: { ...process.env, KODY_STATE_ROOT: stateRoot, KODY_OBSERVER_CI_STATUS: "healthy", KODY_OBSERVER_NOW: "2026-07-14T12:00:00.000Z" },
        encoding: "utf8",
      });
      assert.equal(result.status, 0, result.stderr);
      assert.equal(capabilityResult(result.stdout).facts.finding.status, "resolved");
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }
  });

  it("reports stale agency items as an open agency-flow Finding", async () => {
    const cwd = await mkdtemp(join(tmpdir(), "kody-agency-flow-stale-"));
    const stateRoot = join(cwd, "state-root");
    try {
      mkdirSync(stateRoot, { recursive: true });
      writeFileSync(join(cwd, "kody.config.json"), `${JSON.stringify({
        github: { owner: "A-Guy", repo: "example" },
        state: { path: "example" },
      })}\n`);
      const result = spawnSync("bash", [agencyFlowScriptPath.pathname], {
        cwd,
        env: {
          ...process.env,
          KODY_STATE_ROOT: stateRoot,
          KODY_AGENCY_FLOW_NOW: "2026-07-14T12:00:00.000Z",
          KODY_AGENCY_FLOW_ITEMS_JSON: JSON.stringify([
            { kind: "stale-review-pr", label: "Review PR #9 open since 2026-07-10", url: "https://example.test/pr/9" },
            { kind: "unanswered-request", label: "Request issue #8 open since 2026-07-10", url: "https://example.test/issues/8" },
          ]),
        },
        encoding: "utf8",
      });

      assert.equal(result.status, 0, result.stderr);
      const output = capabilityResult(result.stdout);
      assert.equal(output.status, "fail");
      assert.equal(output.facts.finding.id, "finding-agency-flow");
      assert.equal(output.facts.finding.status, "open");
      const observation = JSON.parse(await readFile(join(stateRoot, "example", "agency", "observations", "obs-agency-flow-20260714t120000000z.json"), "utf8"));
      assert.equal(observation.status, "unhealthy");
      assert.equal(observation.evidence.length, 2);
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }
  });

  it("does not create an agency-flow Finding when the pipeline is clear", async () => {
    const cwd = await mkdtemp(join(tmpdir(), "kody-agency-flow-clear-"));
    const stateRoot = join(cwd, "state-root");
    try {
      mkdirSync(stateRoot, { recursive: true });
      writeFileSync(join(cwd, "kody.config.json"), `${JSON.stringify({ github: { owner: "A-Guy", repo: "example" }, state: { path: "example" } })}\n`);
      const result = spawnSync("bash", [agencyFlowScriptPath.pathname], {
        cwd,
        env: {
          ...process.env,
          KODY_STATE_ROOT: stateRoot,
          KODY_AGENCY_FLOW_NOW: "2026-07-14T12:00:00.000Z",
          KODY_AGENCY_FLOW_ITEMS_JSON: "[]",
        },
        encoding: "utf8",
      });
      assert.equal(result.status, 0, result.stderr);
      const output = capabilityResult(result.stdout);
      assert.equal(output.status, "pass");
      assert.equal(output.facts.finding, undefined);
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }
  });

  it("resolves the agency-flow Finding once a report exists and the pipeline clears", async () => {
    const cwd = await mkdtemp(join(tmpdir(), "kody-agency-flow-recovery-"));
    const stateRoot = join(cwd, "state-root");
    try {
      const runDir = join(stateRoot, "example", "reports", "finding-agency-flow", "runs");
      mkdirSync(runDir, { recursive: true });
      writeFileSync(join(runDir, "2026-07-14T11-45-00Z.md"), reportMarkdown({
        title: "Agency pipeline has stale items",
        data: { finding: { id: "finding-agency-flow", status: "open" } },
      }));
      writeFileSync(join(cwd, "kody.config.json"), `${JSON.stringify({ github: { owner: "A-Guy", repo: "example" }, state: { path: "example" } })}\n`);
      const result = spawnSync("bash", [agencyFlowScriptPath.pathname], {
        cwd,
        env: {
          ...process.env,
          KODY_STATE_ROOT: stateRoot,
          KODY_AGENCY_FLOW_NOW: "2026-07-14T12:00:00.000Z",
          KODY_AGENCY_FLOW_ITEMS_JSON: "[]",
        },
        encoding: "utf8",
      });
      assert.equal(result.status, 0, result.stderr);
      assert.equal(capabilityResult(result.stdout).facts.finding.status, "resolved");
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }
  });

  it("loads Finding reports for the operating loop", async () => {
    const cwd = await mkdtemp(join(tmpdir(), "kody-operate-findings-loader-"));
    const stateRoot = join(cwd, "state-root");
    try {
      const findingRuns = join(stateRoot, "example", "reports", "finding-ci", "runs");
      const learningRuns = join(stateRoot, "example", "reports", "learning-ci", "runs");
      mkdirSync(findingRuns, { recursive: true });
      mkdirSync(learningRuns, { recursive: true });
      writeFileSync(join(findingRuns, "2026-07-14T12-00-00Z.md"), reportMarkdown({ data: { finding: { id: "finding-ci", status: "open", title: "CI failing" } } }));
      writeFileSync(join(learningRuns, "2026-07-14T12-00-00Z.md"), reportMarkdown({ type: "learning", data: { learning: { id: "learning-ci" } } }));
      writeFileSync(join(cwd, "kody.config.json"), `${JSON.stringify({ github: { owner: "A-Guy", repo: "example" }, state: { path: "example" }, company: { activeCapabilities: ["dev-ci-health"] } })}\n`);

      const result = spawnSync("bash", [operatingLoaderPath.pathname], {
        cwd,
        env: { ...process.env, KODY_STATE_ROOT: stateRoot },
        encoding: "utf8",
      });
      assert.equal(result.status, 0, result.stderr);
      const loaded = JSON.parse(await readFile(join(cwd, ".kody-engine", "agency-findings.json"), "utf8"));
      assert.deepEqual(loaded.findings.map((finding) => finding.id), ["finding-ci"]);
      assert.equal(loaded.findings[0].reportRunId, "2026-07-14T12-00-00Z");
      assert.equal(loaded.availableCapabilities[0].name, "dev-ci-health");
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }
  });
});
