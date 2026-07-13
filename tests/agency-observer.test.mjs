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
const sourceHealthScriptPath = new URL(
  "../capabilities/repo-source-health/run-repo-source-health.sh",
  import.meta.url,
);
const observerWorkflowPath = new URL("../workflows/agency-observer/workflow.json", import.meta.url);
const operatingProfilePath = new URL("../capabilities/operate-findings/profile.json", import.meta.url);
const operatingLoaderPath = new URL("../capabilities/operate-findings/load-agency-findings.sh", import.meta.url);
const observerScriptPath = new URL("../capabilities/observe-repo-ci/run-observe-repo-ci.sh", import.meta.url);

describe("agency observer and operating loops", () => {
  it("defines both responsibilities as ordinary Loop templates", async () => {
    const observer = JSON.parse(await readFile(observerGoalPath, "utf8"));
    const operating = JSON.parse(await readFile(operatingGoalPath, "utf8"));
    const sourceHealthCapability = JSON.parse(await readFile(sourceHealthProfilePath, "utf8"));
    const observeCapability = JSON.parse(await readFile(observerProfilePath, "utf8"));
    const operateCapability = JSON.parse(await readFile(operatingProfilePath, "utf8"));
    const observerWorkflow = JSON.parse(await readFile(observerWorkflowPath, "utf8"));

    assert.equal(observer.scheduleMode, "agentLoop");
    assert.equal(observer.type, "agentLoop");
    assert.deepEqual(observer.loopTarget, { type: "workflow", id: "agency-observer" });
    assert.deepEqual(observer.capabilities, []);
    assert.deepEqual(
      observerWorkflow.steps.map((step) => step.capability),
      ["repo-source-health", "observe-repo-ci"],
    );
    assert.equal(operating.scheduleMode, "agentLoop");
    assert.deepEqual(operating.capabilities, ["operate-findings"]);
    assert.equal(sourceHealthCapability.capabilityKind, "observe");
    assert.deepEqual(sourceHealthCapability.writesTo, ["commit-status"]);
    assert.equal(observeCapability.capabilityKind, "observe");
    assert.deepEqual(observeCapability.writesTo, ["observations", "findings"]);
    assert.equal(operateCapability.capabilityKind, "act");
    assert.deepEqual(operateCapability.capabilityTools, [
      "read_check_runs",
      "ensure_issue",
      "start_capability",
      "ensure_comment",
    ]);
    assert.equal(operateCapability.capabilityToolMode, "append");
    assert.deepEqual(operateCapability.scripts.preflight[0], {
      script: "loadCapabilityState",
    });
    assert.deepEqual(operateCapability.scripts.preflight[1], {
      shell: "load-agency-findings.sh",
    });
    assert.deepEqual(operateCapability.readsFrom, ["findings", "intents", "goals"]);
    assert.deepEqual(operateCapability.writesTo, ["findings", "learnings"]);
  });

  it("publishes configured source-check failure without failing the observer workflow", async () => {
    const cwd = await mkdtemp(join(tmpdir(), "kody-repo-source-health-"));
    try {
      const bin = join(cwd, "bin");
      const ghLog = join(cwd, "gh.log");
      mkdirSync(bin, { recursive: true });
      writeFileSync(
        join(cwd, "kody.config.json"),
        `${JSON.stringify({
          github: { owner: "A-Guy", repo: "example" },
          quality: {
            typecheck: 'node -e "process.exit(0)"',
            lint: 'node -e "process.exit(7)"',
            testUnit: 'node -e "process.exit(0)"',
          },
        })}\n`,
      );
      const gh = join(bin, "gh");
      writeFileSync(
        gh,
        `#!/usr/bin/env bash\nprintf '%s\\n' "$*" >> "$GH_LOG"\nif [[ "$*" == *"/commits/"*"/status"* ]]; then\n  printf '%s' '{"statuses":[]}'\nelse\n  printf '%s' '{}'\nfi\n`,
      );
      chmodSync(gh, 0o755);

      const result = spawnSync("bash", [sourceHealthScriptPath.pathname], {
        cwd,
        env: {
          ...process.env,
          PATH: `${bin}:${process.env.PATH}`,
          GH_LOG: ghLog,
          KODY_SOURCE_HEALTH_SHA: "abc123",
          KODY_SOURCE_HEALTH_SKIP_INSTALL: "1",
        },
        encoding: "utf8",
      });

      assert.equal(result.status, 0, result.stderr);
      assert.match(result.stdout, /REPO_SOURCE_HEALTH status=failure/);
      assert.match(result.stdout, /failed=lint/);
      const calls = await readFile(ghLog, "utf8");
      assert.match(calls, /--method POST repos\/A-Guy\/example\/statuses\/abc123/);
      assert.match(calls, /-f state=failure/);
      assert.match(calls, /-f context=Kody Source Health/);
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }
  });

  it("does not rerun source checks for a terminal status on the current commit", async () => {
    const cwd = await mkdtemp(join(tmpdir(), "kody-repo-source-health-dedup-"));
    try {
      const bin = join(cwd, "bin");
      const ghLog = join(cwd, "gh.log");
      mkdirSync(bin, { recursive: true });
      writeFileSync(
        join(cwd, "kody.config.json"),
        `${JSON.stringify({
          github: { owner: "A-Guy", repo: "example" },
          quality: { typecheck: 'node -e "process.exit(9)"' },
        })}\n`,
      );
      const gh = join(bin, "gh");
      writeFileSync(
        gh,
        `#!/usr/bin/env bash\nprintf '%s\\n' "$*" >> "$GH_LOG"\nif [[ "$*" == *"/commits/"*"/status"* ]]; then\n  printf '%s' '{"statuses":[{"context":"Kody Source Health","state":"success"}]}'\nelse\n  printf '%s' '{}'\nfi\n`,
      );
      chmodSync(gh, 0o755);

      const result = spawnSync("bash", [sourceHealthScriptPath.pathname], {
        cwd,
        env: {
          ...process.env,
          PATH: `${bin}:${process.env.PATH}`,
          GH_LOG: ghLog,
          KODY_SOURCE_HEALTH_SHA: "abc123",
          KODY_SOURCE_HEALTH_SKIP_INSTALL: "1",
        },
        encoding: "utf8",
      });

      assert.equal(result.status, 0, result.stderr);
      assert.match(result.stdout, /REPO_SOURCE_HEALTH status=success skipped=already-checked/);
      assert.doesNotMatch(await readFile(ghLog, "utf8"), /--method POST/);
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }
  });

  it("creates one finding, updates it, and hands recovery to verification", async () => {
    const cwd = await mkdtemp(join(tmpdir(), "kody-agency-observer-"));
    const stateRoot = join(cwd, "state-root");
    try {
      mkdirSync(stateRoot, { recursive: true });
      writeFileSync(
        join(cwd, "kody.config.json"),
        `${JSON.stringify({
          github: { owner: "A-Guy", repo: "example" },
          state: { path: "example" },
          company: { activeCapabilities: ["dev-ci-health"] },
        })}\n`,
      );

      const run = (status, at) =>
        spawnSync("bash", [observerScriptPath.pathname], {
          cwd,
          env: {
            ...process.env,
            KODY_STATE_ROOT: stateRoot,
            KODY_OBSERVER_CI_STATUS: status,
            KODY_OBSERVER_NOW: at,
          },
          encoding: "utf8",
        });

      const first = run("unhealthy", "2026-07-12T10:00:00.000Z");
      assert.equal(first.status, 0, first.stderr);
      const second = run("unhealthy", "2026-07-12T10:15:00.000Z");
      assert.equal(second.status, 0, second.stderr);

      const findingPath = join(
        stateRoot,
        "example",
        "agency",
        "findings",
        "finding-repo-ci-main.json",
      );
      const open = JSON.parse(await readFile(findingPath, "utf8"));
      assert.equal(open.status, "open");
      assert.equal(open.phase, "observed");
      assert.equal(open.observationIds.length, 2);

      const healthy = run("healthy", "2026-07-12T10:30:00.000Z");
      assert.equal(healthy.status, 0, healthy.stderr);
      const resolved = JSON.parse(await readFile(findingPath, "utf8"));
      assert.equal(resolved.status, "in_progress");
      assert.equal(resolved.phase, "verifying");
      assert.equal(resolved.observationIds.length, 3);
      assert.equal(resolved.resolvedAt, undefined);

      writeFileSync(
        findingPath,
        `${JSON.stringify({
          ...resolved,
          decision: { action: "dev-ci-health" },
          deliveryRunId: "123",
        })}\n`,
      );

      const redAgain = run("unhealthy", "2026-07-12T10:45:00.000Z");
      assert.equal(redAgain.status, 0, redAgain.stderr);
      const reopened = JSON.parse(await readFile(findingPath, "utf8"));
      assert.equal(reopened.status, "open");
      assert.equal(reopened.phase, "observed");
      assert.equal(reopened.decision, undefined);
      assert.equal(reopened.deliveryRunId, undefined);

      writeFileSync(
        findingPath,
        `${JSON.stringify({
          ...reopened,
          decision: { action: "stale" },
          deliveryRunId: "stale",
        })}\n`,
      );
      const stillRed = run("unhealthy", "2026-07-12T11:00:00.000Z");
      assert.equal(stillRed.status, 0, stillRed.stderr);
      const observed = JSON.parse(await readFile(findingPath, "utf8"));
      assert.equal(observed.decision, undefined);
      assert.equal(observed.deliveryRunId, undefined);

      writeFileSync(
        findingPath,
        `${JSON.stringify({
          ...observed,
          phase: "deciding",
          decision: { action: "escalate", reason: "old decision" },
        })}\n`,
      );
      const staleDecision = run("unhealthy", "2026-07-12T11:05:00.000Z");
      assert.equal(staleDecision.status, 0, staleDecision.stderr);
      const reconsidered = JSON.parse(await readFile(findingPath, "utf8"));
      assert.equal(reconsidered.status, "open");
      assert.equal(reconsidered.phase, "observed");
      assert.equal(reconsidered.decision, undefined);

      writeFileSync(
        findingPath,
        `${JSON.stringify({
          ...reconsidered,
          status: "resolved",
          phase: "closed",
          resolvedAt: "2026-07-12T11:05:00.000Z",
        })}\n`,
      );
      const healthyAfterResolution = run("healthy", "2026-07-12T11:15:00.000Z");
      assert.equal(healthyAfterResolution.status, 0, healthyAfterResolution.stderr);
      const stillClosed = JSON.parse(await readFile(findingPath, "utf8"));
      assert.equal(stillClosed.status, "resolved");
      assert.equal(stillClosed.phase, "closed");
      assert.equal(stillClosed.resolvedAt, "2026-07-12T11:05:00.000Z");
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }
  });

  it("records healthy evidence without inventing a finding", async () => {
    const cwd = await mkdtemp(join(tmpdir(), "kody-agency-observer-healthy-"));
    const stateRoot = join(cwd, "state-root");
    try {
      mkdirSync(stateRoot, { recursive: true });
      writeFileSync(
        join(cwd, "kody.config.json"),
        `${JSON.stringify({
          github: { owner: "A-Guy", repo: "example" },
          state: { path: "example" },
        })}\n`,
      );
      const result = spawnSync("bash", [observerScriptPath.pathname], {
        cwd,
        env: {
          ...process.env,
          KODY_STATE_ROOT: stateRoot,
          KODY_OBSERVER_CI_STATUS: "healthy",
          KODY_OBSERVER_NOW: "2026-07-12T10:00:00.000Z",
        },
        encoding: "utf8",
      });
      assert.equal(result.status, 0, result.stderr);
      await assert.rejects(
        readFile(
          join(
            stateRoot,
            "example",
            "agency",
            "findings",
            "finding-repo-ci-main.json",
          ),
          "utf8",
        ),
        { code: "ENOENT" },
      );
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }
  });

  it("ignores the agency runner when selecting repository CI evidence", async () => {
    const cwd = await mkdtemp(join(tmpdir(), "kody-agency-observer-runs-"));
    const stateRoot = join(cwd, "state-root");
    try {
      mkdirSync(stateRoot, { recursive: true });
      writeFileSync(
        join(cwd, "kody.config.json"),
        `${JSON.stringify({
          github: { owner: "A-Guy", repo: "example" },
          git: { defaultBranch: "dev" },
          state: { path: "example" },
        })}\n`,
      );
      const result = spawnSync("bash", [observerScriptPath.pathname], {
        cwd,
        env: {
          ...process.env,
          KODY_STATE_ROOT: stateRoot,
          KODY_OBSERVER_CI_RUNS_JSON: JSON.stringify([
            {
              name: "kody",
              status: "in_progress",
              conclusion: "",
              url: "https://example.test/kody",
              databaseId: 1,
            },
            {
              name: "Test CI",
              status: "completed",
              conclusion: "success",
              url: "https://example.test/ci",
              databaseId: 2,
            },
          ]),
          KODY_OBSERVER_NOW: "2026-07-12T10:00:00.000Z",
        },
        encoding: "utf8",
      });
      assert.equal(result.status, 0, result.stderr);
      assert.match(result.stdout, /status=healthy/);
      const observation = JSON.parse(
        await readFile(
          join(
            stateRoot,
            "example",
            "agency",
            "observations",
            "obs-ci-dev-20260712t100000000z.json",
          ),
          "utf8",
        ),
      );
      assert.equal(observation.status, "healthy");
      assert.equal(observation.evidence[0].label, "Test CI");
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }
  });

  it("uses a failing commit status as repository CI evidence", async () => {
    const cwd = await mkdtemp(join(tmpdir(), "kody-agency-observer-status-"));
    const stateRoot = join(cwd, "state-root");
    try {
      mkdirSync(stateRoot, { recursive: true });
      writeFileSync(
        join(cwd, "kody.config.json"),
        `${JSON.stringify({
          github: { owner: "A-Guy", repo: "example" },
          git: { defaultBranch: "dev" },
          state: { path: "example" },
        })}\n`,
      );
      const result = spawnSync("bash", [observerScriptPath.pathname], {
        cwd,
        env: {
          ...process.env,
          KODY_STATE_ROOT: stateRoot,
          KODY_OBSERVER_COMMIT_STATUS_JSON: JSON.stringify({
            state: "failure",
            sha: "abc123",
            statuses: [
              {
                context: "Source Tests",
                state: "failure",
                target_url: "https://example.test/source-tests",
              },
            ],
          }),
          KODY_OBSERVER_CI_RUNS_JSON: JSON.stringify([
            {
              name: "Test CI",
              status: "completed",
              conclusion: "success",
              url: "https://example.test/ci",
              databaseId: 2,
            },
          ]),
          KODY_OBSERVER_NOW: "2026-07-12T10:00:00.000Z",
        },
        encoding: "utf8",
      });
      assert.equal(result.status, 0, result.stderr);
      assert.match(result.stdout, /status=unhealthy/);
      const observation = JSON.parse(
        await readFile(
          join(
            stateRoot,
            "example",
            "agency",
            "observations",
            "obs-ci-dev-20260712t100000000z.json",
          ),
          "utf8",
        ),
      );
      assert.equal(observation.evidence[0].kind, "commit-status");
      assert.equal(observation.evidence[0].label, "Source Tests");
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }
  });

  it("loads active findings from the configured state repo for the operating agent", async () => {
    const cwd = await mkdtemp(join(tmpdir(), "kody-operate-findings-loader-"));
    const stateRoot = join(cwd, "state-root");
    try {
      mkdirSync(join(stateRoot, "example", "agency", "findings"), {
        recursive: true,
      });
      writeFileSync(
        join(cwd, "kody.config.json"),
        `${JSON.stringify({
          github: { owner: "A-Guy", repo: "example" },
          state: { path: "example" },
          company: { activeCapabilities: ["dev-ci-health"] },
        })}\n`,
      );
      writeFileSync(
        join(
          stateRoot,
          "example",
          "agency",
          "findings",
          "finding-ci.json",
        ),
        `${JSON.stringify({ id: "finding-ci", status: "open", phase: "observed" })}\n`,
      );
      writeFileSync(
        join(
          stateRoot,
          "example",
          "agency",
          "findings",
          "finding-closed.json",
        ),
        `${JSON.stringify({ id: "finding-closed", status: "resolved", phase: "closed" })}\n`,
      );

      const result = spawnSync("bash", [operatingLoaderPath.pathname], {
        cwd,
        env: { ...process.env, KODY_STATE_ROOT: stateRoot },
        encoding: "utf8",
      });
      assert.equal(result.status, 0, result.stderr);
      const loaded = JSON.parse(
        await readFile(join(cwd, ".kody-engine", "agency-findings.json"), "utf8"),
      );
      assert.deepEqual(loaded.findings.map((finding) => finding.id), [
        "finding-ci",
      ]);
      assert.equal(loaded.statePath, "example");
      assert.equal(loaded.availableCapabilities[0].name, "dev-ci-health");
      assert.match(loaded.availableCapabilities[0].describe, /CI/i);
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }
  });

  it("accepts raw base64 file responses from the state repo", async () => {
    const cwd = await mkdtemp(join(tmpdir(), "kody-operate-findings-remote-"));
    try {
      const bin = join(cwd, "bin");
      mkdirSync(bin, { recursive: true });
      writeFileSync(
        join(cwd, "kody.config.json"),
        `${JSON.stringify({
          github: { owner: "A-Guy", repo: "example" },
          state: { repo: "A-Guy/state", path: "example" },
        })}\n`,
      );
      const gh = join(bin, "gh");
      writeFileSync(
        gh,
        `#!/usr/bin/env bash\nif [[ "$*" == *"finding-ci.json"* ]]; then\n  printf '%s' "$RAW_FILE"\nelse\n  printf '%s' "$FINDING_LIST"\nfi\n`,
      );
      chmodSync(gh, 0o755);
      const finding = { id: "finding-ci", status: "open", phase: "observed" };
      const result = spawnSync("bash", [operatingLoaderPath.pathname], {
        cwd,
        env: {
          ...process.env,
          PATH: `${bin}:${process.env.PATH}`,
          RAW_FILE: Buffer.from(
            Buffer.from(JSON.stringify(finding)).toString("base64"),
          ).toString("base64"),
          FINDING_LIST: JSON.stringify([
            { type: "file", name: "finding-ci.json" },
          ]),
        },
        encoding: "utf8",
      });
      assert.equal(result.status, 0, result.stderr);
      const loaded = JSON.parse(
        await readFile(join(cwd, ".kody-engine", "agency-findings.json"), "utf8"),
      );
      assert.deepEqual(loaded.findings, [finding]);
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }
  });
});
