import assert from "node:assert/strict";
import { chmodSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { readFile } from "node:fs/promises";
import { mkdtemp } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, it } from "node:test";

const profilePath = new URL("../implementations/agency-supervisor/runtime.json", import.meta.url);
const implementationPath = new URL("../implementations/agency-supervisor/definition.json", import.meta.url);
const scriptPath = new URL("../implementations/agency-supervisor/run-agency-supervisor.sh", import.meta.url);
const goalPath = new URL("../goals/templates/agency-supervision-loop/state.json", import.meta.url);
const workflowPath = new URL("../workflows/agency-supervision-loop/workflow.json", import.meta.url);

function resultFrom(stdout) {
  const line = stdout.split("\n").find((item) => item.startsWith("KODY_CAPABILITY_RESULT="));
  return line ? JSON.parse(line.slice("KODY_CAPABILITY_RESULT=".length)) : null;
}

function writeJson(root, relative, value) {
  const file = join(root, "example", relative);
  mkdirSync(join(file, ".."), { recursive: true });
  writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
}

function writeReport(root, slug, value, generatedAt = "2026-07-18T09:00:00.000Z") {
  const file = join(root, "example", "reports", slug, "runs", `${generatedAt.replaceAll(":", "-")}.md`);
  mkdirSync(join(file, ".."), { recursive: true });
  writeFileSync(file, [
    "---",
    `generatedAt: ${JSON.stringify(generatedAt)}`,
    "reportType: finding",
    "reportTypeVersion: 1",
    "producer:",
    "  model: agency-observer",
    "  capability: observe-repo-ci",
    "---",
    `# ${slug}`,
    "",
    "## Report data",
    "```json",
    JSON.stringify({ finding: value }, null, 2),
    "```",
    "",
  ].join("\n"));
}

describe("agency supervisor", () => {
  it("defines an hourly supervisor loop and Report-based output", async () => {
    const profile = JSON.parse(await readFile(profilePath, "utf8"));
    const implementation = JSON.parse(await readFile(implementationPath, "utf8"));
    const goal = JSON.parse(await readFile(goalPath, "utf8"));
    const workflow = JSON.parse(await readFile(workflowPath, "utf8"));

    assert.equal(implementation.id, "agency-supervisor");
    assert.equal(profile.capabilityKind, "observe");
    assert.equal(implementation.type, "script");
    assert.equal(implementation.agentRef, undefined);
    assert.deepEqual(profile.scripts.preflight, [{ shell: "run-agency-supervisor.sh" }, { script: "skipAgent" }]);
    assert.equal(goal.schedule, "1h");
    assert.deepEqual(goal.loopTarget, { type: "workflow", id: "agency-supervision-loop" });
    assert.deepEqual(workflow.steps[0].report, {
      type: "supervision",
      version: 1,
      owner: "agency-supervisor",
      slugFact: "supervision.subject",
      titleFact: "supervision.subject",
      publishWhenFact: "supervision.subject",
      reviewStatus: "info",
      reviewArea: "agency-supervision",
    });
  });

  it("reports a healthy agency when evidence is fresh and synchronized", async () => {
    const cwd = await mkdtemp(join(tmpdir(), "kody-agency-supervisor-"));
    const stateRoot = join(cwd, "state-root");
    try {
      writeFileSync(join(cwd, "kody.config.json"), `${JSON.stringify({
        github: { owner: "A-Guy", repo: "example" },
        state: { path: "example" },
      })}\n`);
      writeJson(stateRoot, "runs/index.json", {
        runs: [
          { subjectId: "agency-observer", status: "success", updatedAt: "2026-07-18T08:45:00.000Z" },
          { subjectId: "agency-operating-loop", status: "success", updatedAt: "2026-07-18T08:45:00.000Z" },
        ],
      });
      writeJson(stateRoot, "agency/observations/obs-ci-main.json", {
        observerId: "agency-observer",
        observedAt: "2026-07-18T08:30:00.000Z",
        status: "healthy",
      });
      writeReport(stateRoot, "finding-ci", {
        id: "finding-ci",
        status: "resolved",
        observedAt: "2026-07-18T08:30:00.000Z",
        operatorActivityAt: "2026-07-18T08:40:00.000Z",
      });
      const result = spawnSync("bash", [scriptPath.pathname], {
        cwd,
        env: { ...process.env, KODY_STATE_ROOT: stateRoot, KODY_SUPERVISOR_NOW: "2026-07-18T09:00:00.000Z" },
        encoding: "utf8",
      });
      assert.equal(result.status, 0, result.stderr);
      const output = resultFrom(result.stdout);
      assert.equal(output.status, "pass");
      assert.equal(output.facts.supervision.status, "healthy");
      assert.deepEqual(output.facts.supervision.violations, []);
      assert.match(result.stdout, /AGENCY_SUPERVISOR status=healthy/);
      assert.ok(await readFile(join(stateRoot, "example", "agency", "observations", "obs-supervisor-20260718t090000000z.json"), "utf8"));
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }
  });

  it("blocks when observation evidence is stale and never repairs implicitly", async () => {
    const cwd = await mkdtemp(join(tmpdir(), "kody-agency-supervisor-blocked-"));
    const stateRoot = join(cwd, "state-root");
    try {
      writeFileSync(join(cwd, "kody.config.json"), `${JSON.stringify({
        github: { owner: "A-Guy", repo: "example" },
        state: { path: "example" },
      })}\n`);
      writeJson(stateRoot, "agency/observations/obs-ci-main.json", {
        observerId: "agency-observer",
        observedAt: "2026-07-18T06:00:00.000Z",
        status: "healthy",
      });
      const result = spawnSync("bash", [scriptPath.pathname], {
        cwd,
        env: { ...process.env, KODY_STATE_ROOT: stateRoot, KODY_SUPERVISOR_NOW: "2026-07-18T09:00:00.000Z" },
        encoding: "utf8",
      });
      assert.equal(result.status, 0, result.stderr);
      const output = resultFrom(result.stdout);
      assert.equal(output.status, "blocked");
      assert.ok(output.facts.supervision.violations.some((item) => item.code === "stale-observation"));
      assert.deepEqual(output.facts.supervision.repairs, []);
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }
  });
});
