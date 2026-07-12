import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import { mkdtemp, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, it } from "node:test";

const observerGoalPath = new URL("../goals/templates/agency-observer/state.json", import.meta.url);
const operatingGoalPath = new URL("../goals/templates/agency-operating-loop/state.json", import.meta.url);
const observerProfilePath = new URL("../capabilities/observe-repo-ci/profile.json", import.meta.url);
const operatingProfilePath = new URL("../capabilities/operate-findings/profile.json", import.meta.url);
const observerScriptPath = new URL("../capabilities/observe-repo-ci/run-observe-repo-ci.sh", import.meta.url);

describe("agency observer and operating loops", () => {
  it("defines both responsibilities as ordinary Loop templates", async () => {
    const observer = JSON.parse(await readFile(observerGoalPath, "utf8"));
    const operating = JSON.parse(await readFile(operatingGoalPath, "utf8"));
    const observeCapability = JSON.parse(await readFile(observerProfilePath, "utf8"));
    const operateCapability = JSON.parse(await readFile(operatingProfilePath, "utf8"));

    assert.equal(observer.scheduleMode, "agentLoop");
    assert.deepEqual(observer.capabilities, ["observe-repo-ci"]);
    assert.equal(operating.scheduleMode, "agentLoop");
    assert.deepEqual(operating.capabilities, ["operate-findings"]);
    assert.equal(observeCapability.capabilityKind, "observe");
    assert.deepEqual(observeCapability.writesTo, ["observations", "findings"]);
    assert.equal(operateCapability.capabilityKind, "act");
    assert.deepEqual(operateCapability.capabilityTools, [
      "read_check_runs",
      "ensure_issue",
      "start_capability",
      "ensure_comment",
    ]);
    assert.deepEqual(operateCapability.readsFrom, ["findings", "intents", "goals"]);
    assert.deepEqual(operateCapability.writesTo, ["findings", "learnings"]);
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
});
