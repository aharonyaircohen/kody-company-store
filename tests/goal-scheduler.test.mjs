import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { mkdtemp } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { describe, it } from "node:test";

const scriptPath = new URL("../.kody/executables/goal-scheduler/scheduler.sh", import.meta.url);

function installStubs(cwd) {
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
  writeFileSync(gh, "#!/usr/bin/env bash\nexit 0\n", { mode: 0o755 });

  return binDir;
}

function writeConfig(cwd, activeGoals) {
  writeFileSync(
    join(cwd, "kody.config.json"),
    `${JSON.stringify({ company: { activeGoals } }, null, 2)}\n`,
  );
}

function runScheduler(cwd, binDir, logFile, now) {
  rmSync(logFile, { force: true });
  const result = spawnSync("bash", [scriptPath.pathname], {
    cwd,
    env: {
      ...process.env,
      PATH: `${binDir}${process.env.PATH ? `:${process.env.PATH}` : ""}`,
      KODY_LOG: logFile,
      KODY_GOAL_SCHEDULER_NOW: now,
      KODY_GOAL_SCHEDULER_SKIP_PERSIST: "1",
    },
    encoding: "utf8",
  });
  const calls = existsSync(logFile) ? readFileSync(logFile, "utf8").trim().split("\n").filter(Boolean) : [];
  return { result, calls };
}

function readGoal(cwd, goalId) {
  return JSON.parse(readFileSync(join(cwd, ".kody", "goals", "instances", goalId, "state.json"), "utf8"));
}

function writeGoal(cwd, goalId, state) {
  const file = join(cwd, ".kody", "goals", "instances", goalId, "state.json");
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
});
