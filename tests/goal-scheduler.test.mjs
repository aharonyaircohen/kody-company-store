import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { mkdtemp } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { describe, it } from "node:test";

const scriptPath = new URL("../.kody/executables/goal-scheduler/scheduler.sh", import.meta.url);

function installStubs(cwd, ghScript = "#!/usr/bin/env bash\nexit 0\n") {
  const binDir = join(cwd, "bin");
  mkdirSync(binDir, { recursive: true });

  const engine = join(binDir, "kody-engine");
  writeFileSync(
    engine,
    [
      "#!/usr/bin/env bash",
      'echo "kody-engine $*" >> "$KODY_LOG"',
      "exit 0",
      "",
    ].join("\n"),
    { mode: 0o755 },
  );

  const gh = join(binDir, "gh");
  writeFileSync(gh, ghScript, { mode: 0o755 });

  return binDir;
}

function writeConfig(cwd, activeGoals) {
  writeFileSync(
    join(cwd, "kody.config.json"),
    `${JSON.stringify({ company: { activeGoals } }, null, 2)}\n`,
  );
}

function runScheduler(cwd, binDir, logFile, now, extraEnv = {}) {
  rmSync(logFile, { force: true });
  const result = spawnSync("bash", [scriptPath.pathname], {
    cwd,
    env: {
      ...process.env,
      PATH: `${binDir}${process.env.PATH ? `:${process.env.PATH}` : ""}`,
      KODY_LOG: logFile,
      KODY_GOAL_SCHEDULER_NOW: now,
      KODY_GOAL_SCHEDULER_SKIP_PERSIST: "1",
      ...extraEnv,
    },
    encoding: "utf8",
  });
  const calls = existsSync(logFile) ? readFileSync(logFile, "utf8").trim().split("\n").filter(Boolean) : [];
  return { result, calls };
}

function readGoal(cwd, goalId) {
  return JSON.parse(readFileSync(join(cwd, ".kody", "todos", `${goalId}.json`), "utf8"));
}

function writeGoal(cwd, goalId, state) {
  const file = join(cwd, ".kody", "todos", `${goalId}.json`);
  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, `${JSON.stringify(state, null, 2)}\n`);
}

describe("goal-scheduler", () => {
  it("honors 15-minute Store loop schedules for string activations", async () => {
    const cwd = await mkdtemp(join(tmpdir(), "kody-store-goal-scheduler-"));
    try {
      const logFile = join(cwd, "calls.log");
      const binDir = installStubs(cwd);
      writeConfig(cwd, ["ci-health", "prs-stay-mergeable"]);

      const first = runScheduler(cwd, binDir, logFile, "2026-06-20T12:00:00Z");
      assert.equal(first.result.status, 0, first.result.stderr);
      assert.deepEqual(first.calls, [
        "kody-engine exec goal-manager --goal ci-health",
        "kody-engine exec goal-manager --goal prs-stay-mergeable",
      ]);
      assert.equal(readGoal(cwd, "ci-health").schedule, "15m");
      assert.equal(readGoal(cwd, "prs-stay-mergeable").schedule, "15m");

      for (const goalId of ["ci-health", "prs-stay-mergeable"]) {
        const state = readGoal(cwd, goalId);
        state.scheduleState = {
          mode: "agentLoop",
          lastGoalTickAt: "2026-06-20T12:00:00Z",
          lastDecision: { kind: "idle", reason: "seed", at: "2026-06-20T12:00:00Z" },
          capabilities: {},
        };
        writeGoal(cwd, goalId, state);
      }

      const early = runScheduler(cwd, binDir, logFile, "2026-06-20T12:05:00Z");
      assert.equal(early.result.status, 0, early.result.stderr);
      assert.deepEqual(early.calls, []);
      assert.match(early.result.stdout, /skip ci-health: waiting schedule 15m/);
      assert.match(early.result.stdout, /skip prs-stay-mergeable: waiting schedule 15m/);

      const due = runScheduler(cwd, binDir, logFile, "2026-06-20T12:15:00Z");
      assert.equal(due.result.status, 0, due.result.stderr);
      assert.deepEqual(due.calls, [
        "kody-engine exec goal-manager --goal ci-health",
        "kody-engine exec goal-manager --goal prs-stay-mergeable",
      ]);
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }
  });

  it("runs daily preferred-time loops by local day instead of 24 hours after an idle tick", async () => {
    const cwd = await mkdtemp(join(tmpdir(), "kody-store-goal-scheduler-"));
    try {
      const logFile = join(cwd, "calls.log");
      const binDir = installStubs(cwd);
      writeConfig(cwd, ["daily-web-release-loop"]);
      writeGoal(cwd, "daily-web-release-loop", {
        version: 1,
        managed: true,
        managedModel: "agentLoop",
        state: "active",
        type: "agentLoop",
        destination: { outcome: "daily web release loop", evidence: [] },
        schedule: "1d",
        scheduleMode: "agentLoop",
        loopTarget: { type: "goal", id: "web-release" },
        capabilities: [],
        route: [],
        facts: {},
        blockers: [],
        preferredRunTime: { time: "08:30", timezone: "Asia/Jerusalem" },
      });

      const beforePreferred = runScheduler(cwd, binDir, logFile, "2026-06-27T05:00:00Z");
      assert.equal(beforePreferred.result.status, 0, beforePreferred.result.stderr);
      assert.deepEqual(beforePreferred.calls, []);
      assert.match(
        beforePreferred.result.stdout,
        /skip daily-web-release-loop: waiting preferred time 08:30 Asia\/Jerusalem until 2026-06-27T05:30:00Z/,
      );

      const idleState = readGoal(cwd, "daily-web-release-loop");
      idleState.scheduleState = {
        mode: "agentLoop",
        lastGoalTickAt: "2026-06-27T05:07:36.328Z",
        lastDecision: {
          kind: "idle",
          reason: "waiting preferred time 08:30 Asia/Jerusalem",
          at: "2026-06-27T05:07:36.328Z",
        },
        capabilities: {},
      };
      writeGoal(cwd, "daily-web-release-loop", idleState);

      const afterPreferred = runScheduler(cwd, binDir, logFile, "2026-06-27T06:00:00Z");
      assert.equal(afterPreferred.result.status, 0, afterPreferred.result.stderr);
      assert.deepEqual(afterPreferred.calls, ["kody-engine exec goal-manager --goal daily-web-release-loop"]);
      assert.doesNotMatch(afterPreferred.result.stdout, /waiting schedule 1d/);

      const dispatchedState = readGoal(cwd, "daily-web-release-loop");
      dispatchedState.scheduleState = {
        mode: "agentLoop",
        lastGoalTickAt: "2026-06-27T06:00:00Z",
        lastDecision: {
          kind: "dispatch",
          targetType: "goal",
          targetId: "web-release",
          executable: "goal-manager",
          reason: "preferred time 08:30 Asia/Jerusalem",
          at: "2026-06-27T06:00:00Z",
        },
        capabilities: {},
      };
      writeGoal(cwd, "daily-web-release-loop", dispatchedState);

      const secondSameDay = runScheduler(cwd, binDir, logFile, "2026-06-27T08:00:00Z");
      assert.equal(secondSameDay.result.status, 0, secondSameDay.result.stderr);
      assert.deepEqual(secondSameDay.calls, []);
      assert.match(
        secondSameDay.result.stdout,
        /skip daily-web-release-loop: already dispatched today at preferred time 08:30 Asia\/Jerusalem; next eligible 2026-06-28T05:30:00Z/,
      );
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }
  });

  it("retries GitHub API rate limit failures before giving up", async () => {
    const cwd = await mkdtemp(join(tmpdir(), "kody-store-goal-scheduler-"));
    try {
      const logFile = join(cwd, "calls.log");
      const ghCountFile = join(cwd, "gh-list-count");
      const remoteState = {
        version: 1,
        managed: true,
        managedModel: "agentLoop",
        state: "active",
        type: "standing",
        destination: { outcome: "CI stays healthy", evidence: [] },
        capabilities: [],
        route: [],
        facts: {},
        blockers: [],
      };
      const remoteStateB64 = Buffer.from(`${JSON.stringify(remoteState)}\n`).toString("base64");
      const binDir = installStubs(
        cwd,
        [
          "#!/usr/bin/env bash",
          "set -euo pipefail",
          'if [ "$1" = "api" ] && [ "$2" = "/repos/o/r/contents/base/todos" ]; then',
          '  count="$(cat "$GH_LIST_COUNT" 2>/dev/null || echo 0)"',
          "  count=$((count + 1))",
          '  echo "$count" > "$GH_LIST_COUNT"',
          '  if [ "$count" = "1" ]; then',
          '    echo "gh: API rate limit exceeded for installation ID 1 (HTTP 403)" >&2',
          "    exit 1",
          "  fi",
          '  printf \'[{"name":"ci-health.json","type":"file"}]\\n\'',
          "  exit 0",
          "fi",
          'if [ "$1" = "api" ] && [ "$2" = "/repos/o/r/contents/base/todos/ci-health.json" ]; then',
          '  printf \'{"content":"%s"}\\n\' "$REMOTE_STATE_B64"',
          "  exit 0",
          "fi",
          "echo '{}'",
          "",
        ].join("\n"),
      );
      writeFileSync(
        join(cwd, "kody.config.json"),
        `${JSON.stringify(
          {
            state: { repo: "o/r", path: "base" },
            company: { activeGoals: ["ci-health"] },
          },
          null,
          2,
        )}\n`,
      );

      const run = runScheduler(cwd, binDir, logFile, "2026-06-20T12:00:00Z", {
        KODY_GOAL_SCHEDULER_SKIP_PERSIST: "",
        KODY_GOAL_SCHEDULER_GH_RETRY_DELAYS: "0",
        GH_LIST_COUNT: ghCountFile,
        REMOTE_STATE_B64: remoteStateB64,
      });

      assert.equal(run.result.status, 0, run.result.stderr);
      assert.equal(readFileSync(ghCountFile, "utf8").trim(), "2");
      assert.match(run.result.stderr, /gh rate limited; retrying in 0s/);
      assert.deepEqual(run.calls, ["kody-engine exec goal-manager --goal ci-health"]);
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }
  });
});
