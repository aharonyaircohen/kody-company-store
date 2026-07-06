import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { mkdtemp, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, it } from "node:test";

const storeRoot = new URL("..", import.meta.url).pathname;
const scriptPath = new URL("../capabilities/ai-agency-health-matrix/run-ai-agency-health-matrix.sh", import.meta.url);
const healthGoalPath = new URL("../goals/templates/ai-agency-health/state.json", import.meta.url);

function writeJson(file, value) {
  writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
}

function writeCapability(cwd, slug, profile) {
  const dir = join(cwd, ".kody", "capabilities", slug);
  mkdirSync(dir, { recursive: true });
  writeJson(join(dir, "profile.json"), profile);
  writeFileSync(join(dir, "capability.md"), `# ${slug}\n`);
}

function extractJsonBlock(output) {
  const match = output.match(/```json\n([\s\S]*?)\n```/);
  assert.ok(match, "expected a JSON block in report output");
  return JSON.parse(match[1]);
}

describe("ai-agency-health-matrix", () => {
  it("writes the documented repo-local matrix shape in dry run", async () => {
    const cwd = await mkdtemp(join(tmpdir(), "kody-store-ai-agency-health-matrix-"));
    try {
      mkdirSync(join(cwd, ".kody", "agents"), { recursive: true });
      mkdirSync(join(cwd, ".kody", "jobs"), { recursive: true });
      const stateRoot = join(cwd, "state-root");
      mkdirSync(join(stateRoot, "A-Guy-Web", "jobs"), { recursive: true });
      mkdirSync(join(stateRoot, "A-Guy-Web", "goals", "instances", "ai-agency-health"), { recursive: true });
      writeFileSync(join(cwd, ".kody", "agents", "local-agent.md"), "# Local agent\n");
      writeFileSync(join(cwd, ".kody", "jobs", "stale-job.state.json"), "{}\n");
      writeFileSync(join(stateRoot, "A-Guy-Web", "jobs", "auto-sync.state.json"), "{}\n");
      writeJson(join(stateRoot, "A-Guy-Web", "goals", "instances", "ai-agency-health", "state.json"), {
        state: "active",
      });
      writeJson(join(cwd, "kody.config.json"), {
        github: { owner: "A-Guy-educ", repo: "A-Guy-Web" },
        state: { repo: "A-Guy-educ/kody-state", path: "A-Guy-Web" },
        company: {
          activeAgents: ["cto", "missing-agent"],
          activeCapabilities: ["bug", "local-only", "missing-capability"],
          activeGoals: ["ai-agency-health", "missing-goal"],
        },
      });

      writeCapability(cwd, "bug", { name: "bug", agent: "local-agent" });
      writeCapability(cwd, "local-only", { name: "local-only", agent: "local-agent" });

      const result = spawnSync("bash", [scriptPath.pathname, "--dry-run"], {
        cwd,
        env: {
          ...process.env,
          KODY_STORE_ROOT: storeRoot,
          KODY_STATE_ROOT: stateRoot,
        },
        encoding: "utf8",
      });

      assert.equal(result.status, 0, result.stderr);
      assert.match(result.stdout, /# AI Agency Health Matrix/);
      assert.match(result.stdout, /Report path would be reports\/ai-agency-health-matrix\/runs\//);
      assert.match(result.stdout, / on main\./);
      assert.match(result.stdout, /\| area \| expected \| actual \| health \| proof \| owner \| nextAction \|/);

      const report = extractJsonBlock(result.stdout);
      assert.equal(report.schemaVersion, 1);
      assert.equal(report.repo, "A-Guy-educ/A-Guy-Web");
      assert.equal(report.reportSlug, "ai-agency-health-matrix");
      assert.ok(Array.isArray(report.rows));
      assert.ok(report.rows.length > 0);

      const byKey = new Map(report.rows.map((row) => [`${row.area}:${row.expected}`, row]));

      assert.equal(byKey.get("store:Store catalog")?.health, "healthy");
      assert.equal(byKey.get("agents:cto")?.health, "healthy");
      assert.equal(byKey.get("agents:missing-agent")?.health, "missing");
      assert.equal(byKey.get("capabilities:bug")?.health, "repo-local");
      assert.equal(byKey.get("capabilities:local-only")?.health, "repo-local");
      assert.equal(byKey.get("capabilities:missing-capability")?.health, "missing");
      assert.equal(byKey.get("goals:ai-agency-health")?.health, "healthy");
      assert.match(byKey.get("goals:ai-agency-health")?.proof ?? "", /A-Guy-Web\/goals\/instances\/ai-agency-health/);
      assert.equal(byKey.get("loops:ai-agency-health activation")?.health, "healthy");
      assert.equal(byKey.get("loops:ai-agency-health materialized")?.health, "healthy");
      assert.equal(byKey.get("loops:ai-agency-health scheduler")?.health, "unknown");
      assert.equal(byKey.get("loops:ai-agency-health output")?.health, "unknown");
      assert.equal(byKey.get("loops:ai-agency-health outcome")?.health, "unknown");
      assert.equal(byKey.get("loops:ai-agency-health intent")?.health, "healthy");
      assert.equal(byKey.get("goals:missing-goal")?.health, "missing");
      assert.equal(byKey.get("operators:github.operators")?.health, "missing");
      assert.equal(byKey.get("jobs:state jobs")?.health, "healthy");
      assert.match(byKey.get("jobs:state jobs")?.actual ?? "", /1 state file/);
      assert.equal(byKey.get("jobs:state jobs")?.proof, "A-Guy-Web/jobs");

      for (const row of report.rows) {
        assert.ok(row.area);
        assert.ok(row.expected);
        assert.ok("actual" in row);
        assert.ok(row.health);
        assert.ok("proof" in row);
        assert.ok(row.owner);
        assert.ok(row.nextAction);
      }

      assert.equal(existsSync(join(cwd, "reports", "ai-agency-health-matrix")), false);
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }
  });

  it("proves an active loop only when scheduler state and output report match the goal", async () => {
    const cwd = await mkdtemp(join(tmpdir(), "kody-store-ai-agency-health-matrix-"));
    try {
      const stateRoot = join(cwd, "state-root");
      const statePath = join(stateRoot, "A-Guy-Web");
      mkdirSync(join(statePath, "todos"), { recursive: true });
      mkdirSync(join(statePath, "reports", "ai-agency-health-matrix", "runs"), { recursive: true });

      writeJson(join(cwd, "kody.config.json"), {
        github: { owner: "A-Guy-educ", repo: "A-Guy-Web" },
        state: { repo: "A-Guy-educ/kody-state", path: "A-Guy-Web", branch: "main" },
        company: {
          activeGoals: ["ai-agency-health"],
        },
      });
      writeJson(join(statePath, "todos", "ai-agency-health.json"), {
        managed: true,
        managedModel: "agentLoop",
        state: "active",
        scheduleMode: "agentLoop",
        capabilities: ["ai-agency-health-matrix"],
        destination: {
          outcome: "The current repo's AI Agency is checked regularly and broken wiring is visible before work runs.",
          evidence: [],
        },
        scheduleState: {
          lastGoalTickAt: "2026-06-30T10:00:00Z",
          lastDecision: {
            kind: "dispatch",
            capability: "ai-agency-health-matrix",
            implementation: "ai-agency-health-matrix",
            reason: "ready for loop tick",
            at: "2026-06-30T10:00:00Z",
          },
        },
      });
      writeFileSync(
        join(statePath, "reports", "ai-agency-health-matrix", "runs", "2026-06-30T10-00-00Z.md"),
        [
          "---",
          "slug: ai-agency-health-matrix",
          "status: yellow",
          "---",
          "# AI Agency Health Matrix",
          "",
          "```json",
          JSON.stringify({
            schemaVersion: 1,
            reportSlug: "ai-agency-health-matrix",
            repo: "A-Guy-educ/A-Guy-Web",
            status: "yellow",
            rows: [{ area: "config", expected: "kody.config.json" }],
          }),
          "```",
          "",
        ].join("\n"),
      );

      const result = spawnSync("bash", [scriptPath.pathname, "--dry-run"], {
        cwd,
        env: {
          ...process.env,
          KODY_STORE_ROOT: storeRoot,
          KODY_STATE_ROOT: stateRoot,
        },
        encoding: "utf8",
      });

      assert.equal(result.status, 0, result.stderr);
      const report = extractJsonBlock(result.stdout);
      const byKey = new Map(report.rows.map((row) => [`${row.area}:${row.expected}`, row]));

      assert.equal(byKey.get("loops:ai-agency-health activation")?.health, "healthy");
      assert.equal(byKey.get("loops:ai-agency-health materialized")?.health, "healthy");
      assert.equal(byKey.get("loops:ai-agency-health scheduler")?.health, "healthy");
      assert.equal(byKey.get("loops:ai-agency-health output")?.health, "healthy");
      assert.equal(byKey.get("loops:ai-agency-health outcome")?.health, "healthy");
      assert.equal(byKey.get("loops:ai-agency-health intent")?.health, "healthy");
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }
  });

  it("proves a target loop when scheduler state points to a materialized target goal", async () => {
    const cwd = await mkdtemp(join(tmpdir(), "kody-store-ai-agency-health-matrix-"));
    try {
      const stateRoot = join(cwd, "state-root");
      const statePath = join(stateRoot, "A-Guy-Web");
      mkdirSync(join(statePath, "todos"), { recursive: true });

      writeJson(join(cwd, "kody.config.json"), {
        github: { owner: "A-Guy-educ", repo: "A-Guy-Web" },
        state: { repo: "A-Guy-educ/kody-state", path: "A-Guy-Web", branch: "main" },
        company: {
          activeGoals: ["daily-web-release-loop"],
        },
      });
      writeJson(join(statePath, "todos", "daily-web-release-loop.json"), {
        managed: true,
        managedModel: "agentLoop",
        state: "active",
        type: "agentLoop",
        scheduleMode: "agentLoop",
        loopTarget: { type: "goal", id: "web-release" },
        capabilities: [],
        destination: {
          outcome: "Daily web release loop keeps production release moving.",
          evidence: [],
        },
        scheduleState: {
          lastGoalTickAt: "2026-06-30T10:00:00Z",
          lastDecision: {
            kind: "dispatch",
            targetType: "goal",
            targetId: "web-release-2026-06-30",
            implementation: "goal-manager",
            reason: "ready target loop tick",
            at: "2026-06-30T10:00:00Z",
          },
        },
      });
      writeJson(join(statePath, "todos", "web-release.json"), {
        managed: true,
        managedModel: "goal",
        state: "active",
        type: "web-release",
        destination: {
          outcome: "Prepare, promote, deploy, and verify production.",
          evidence: ["productionDeployed"],
        },
        capabilities: ["release-prepare"],
        route: [],
        facts: {},
        blockers: [],
      });
      writeJson(join(statePath, "todos", "web-release-2026-06-30.json"), {
        managed: true,
        managedModel: "goal",
        state: "active",
        type: "web-release",
        destination: {
          outcome: "Prepare, promote, deploy, and verify production.",
          evidence: ["productionDeployed"],
        },
        capabilities: ["release-prepare"],
        route: [],
        facts: {},
        blockers: [],
      });

      const result = spawnSync("bash", [scriptPath.pathname, "--dry-run"], {
        cwd,
        env: {
          ...process.env,
          KODY_STORE_ROOT: storeRoot,
          KODY_STATE_ROOT: stateRoot,
        },
        encoding: "utf8",
      });

      assert.equal(result.status, 0, result.stderr);
      const report = extractJsonBlock(result.stdout);
      const byKey = new Map(report.rows.map((row) => [`${row.area}:${row.expected}`, row]));

      assert.equal(byKey.get("loops:daily-web-release-loop activation")?.health, "healthy");
      assert.equal(byKey.get("loops:daily-web-release-loop materialized")?.health, "healthy");
      assert.equal(byKey.get("loops:daily-web-release-loop scheduler")?.health, "healthy");
      assert.equal(byKey.get("loops:daily-web-release-loop output")?.health, "healthy");
      assert.equal(byKey.get("loops:daily-web-release-loop outcome")?.health, "healthy");
      assert.equal(byKey.get("loops:daily-web-release-loop intent")?.health, "healthy");
      assert.match(byKey.get("loops:daily-web-release-loop output")?.proof ?? "", /A-Guy-Web\/todos\/web-release-2026-06-30\.json/);
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }
  });

  it("proves a target loop when scheduler state points to a Store goal", async () => {
    const cwd = await mkdtemp(join(tmpdir(), "kody-store-ai-agency-health-matrix-"));
    try {
      const stateRoot = join(cwd, "state-root");
      const statePath = join(stateRoot, "A-Guy-Web");
      mkdirSync(join(statePath, "todos"), { recursive: true });

      writeJson(join(cwd, "kody.config.json"), {
        github: { owner: "A-Guy-educ", repo: "A-Guy-Web" },
        state: { repo: "A-Guy-educ/kody-state", path: "A-Guy-Web", branch: "main" },
        company: {
          activeGoals: ["daily-web-release-loop"],
        },
      });
      writeJson(join(statePath, "todos", "daily-web-release-loop.json"), {
        managed: true,
        managedModel: "agentLoop",
        state: "active",
        type: "agentLoop",
        scheduleMode: "agentLoop",
        loopTarget: { type: "goal", id: "web-release" },
        capabilities: [],
        destination: {
          outcome: "Daily web release loop keeps production release moving.",
          evidence: [],
        },
        scheduleState: {
          lastGoalTickAt: "2026-07-04T00:00:00Z",
          lastDecision: {
            kind: "dispatch",
            targetType: "goal",
            targetId: "web-release",
            action: "goal-manager",
            implementation: "goal-manager",
            reason: "preferred time 02:00 Asia/Jerusalem",
            at: "2026-07-04T00:00:00Z",
          },
        },
      });

      const result = spawnSync("bash", [scriptPath.pathname, "--dry-run"], {
        cwd,
        env: {
          ...process.env,
          KODY_STORE_ROOT: storeRoot,
          KODY_STATE_ROOT: stateRoot,
        },
        encoding: "utf8",
      });

      assert.equal(result.status, 0, result.stderr);
      const report = extractJsonBlock(result.stdout);
      const byKey = new Map(report.rows.map((row) => [`${row.area}:${row.expected}`, row]));

      assert.equal(byKey.get("loops:daily-web-release-loop activation")?.health, "healthy");
      assert.equal(byKey.get("loops:daily-web-release-loop materialized")?.health, "healthy");
      assert.equal(byKey.get("loops:daily-web-release-loop scheduler")?.health, "healthy");
      assert.equal(byKey.get("loops:daily-web-release-loop output")?.health, "healthy");
      assert.equal(byKey.get("loops:daily-web-release-loop output")?.actual, "target goal web-release template");
      assert.match(byKey.get("loops:daily-web-release-loop output")?.proof ?? "", /\.kody\/goals\/templates\/web-release\/state\.json/);
      assert.equal(byKey.get("loops:daily-web-release-loop outcome")?.health, "healthy");
      assert.equal(byKey.get("loops:daily-web-release-loop intent")?.health, "healthy");
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }
  });

  it("uses the matrix capability from the ai-agency-health loop", async () => {
    const goal = JSON.parse(await readFile(healthGoalPath, "utf8"));

    assert.deepEqual(goal.capabilities, ["ai-agency-health-matrix"]);
    assert.match(goal.description, /health matrix/i);
  });
});
