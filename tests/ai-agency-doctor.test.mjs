import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import { mkdtemp } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, it } from "node:test";

const scriptPath = new URL("../implementations/ai-agency-doctor/run-ai-agency-doctor.sh", import.meta.url);

function writeJson(file, value) {
  writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
}

function writeCapability(cwd, slug, profile, files = {}) {
  const dir = join(cwd, ".kody", "capabilities", slug);
  mkdirSync(dir, { recursive: true });
  writeJson(join(dir, "profile.json"), profile);
  writeFileSync(join(dir, "capability.md"), `# ${slug}\n`);
  for (const [name, body] of Object.entries(files)) {
    writeFileSync(join(dir, name), body, { mode: 0o755 });
  }
}

describe("ai-agency-doctor", () => {
  it("reports broken local wiring and Store-only references in dry run", async () => {
    const cwd = await mkdtemp(join(tmpdir(), "kody-store-ai-agency-doctor-"));
    try {
      mkdirSync(join(cwd, ".kody", "agents"), { recursive: true });
      mkdirSync(join(cwd, ".kody", "goals", "templates", "local-loop"), { recursive: true });
      writeFileSync(join(cwd, ".kody", "agents", "coo.md"), "# COO\n");
      writeJson(join(cwd, "kody.config.json"), {
        company: {
          activeAgents: ["coo"],
          activeCapabilities: ["good", "store-only"],
          activeGoals: ["local-loop", "store-loop"],
        },
      });

      writeCapability(
        cwd,
        "good",
        {
          name: "good",
          agent: "coo",
          scripts: { preflight: [{ shell: "good.sh" }] },
        },
        { "good.sh": "#!/usr/bin/env bash\nexit 0\n" },
      );
      writeCapability(cwd, "broken", {
        name: "broken",
        scripts: { preflight: [{ shell: "missing.sh" }] },
      });
      writeJson(join(cwd, ".kody", "goals", "templates", "local-loop", "state.json"), {
        state: "active",
        capabilities: ["good", "unknown-capability"],
      });

      const result = spawnSync("bash", [scriptPath.pathname, "--dry-run"], {
        cwd,
        encoding: "utf8",
      });

      assert.equal(result.status, 0, result.stderr);
      assert.match(result.stdout, /AI Agency Health: Red/);
      assert.match(result.stdout, /capability\.broken\.missing-agent/);
      assert.match(result.stdout, /capability\.broken\.missing-shell\.missing\.sh/);
      assert.match(result.stdout, /active-capability\.store-only\.store-or-missing/);
      assert.match(result.stdout, /active-goal\.store-loop\.store-or-missing/);
      assert.match(result.stdout, /goal-template\.local-loop\.not-inactive/);
      assert.match(result.stdout, /goal-template\.local-loop\.capability-store-or-missing\.unknown-capability/);
      assert.match(result.stdout, /Dry run only; no report write attempted/);
      assert.match(result.stdout, /Report path would be reports\/ai-agency-doctor\/runs\/\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}Z\.md/);
      assert.match(result.stdout, /on kody-state/);
      assert.doesNotMatch(result.stdout, /reports\/ai-agency-doctor\.md/);
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }
  });
});
