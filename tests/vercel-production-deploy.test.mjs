import assert from "node:assert/strict";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { describe, it } from "node:test";

const scriptPath = new URL(
  "../capabilities/vercel-production-deploy/vercel-production-deploy.sh",
  import.meta.url,
);

describe("vercel-production-deploy", () => {
  it("reports neutral failure before exiting", async () => {
    const cwd = await mkdtemp(join(tmpdir(), "kody-vercel-deploy-"));
    try {
      const result = spawnSync("bash", [scriptPath.pathname], {
        cwd,
        env: {
          ...process.env,
          VERCEL_ACCESS_TOKEN: "token",
          VERCEL_ORG_ID: "",
          VERCEL_PROJECT_ID: "project",
        },
        encoding: "utf8",
      });

      assert.equal(result.status, 1);
      const line = result.stdout
        .split(/\r?\n/)
        .find((entry) => entry.startsWith("KODY_CAPABILITY_RESULT="));
      assert.ok(line, "failure result side-channel should be emitted");

      const payload = JSON.parse(line.replace("KODY_CAPABILITY_RESULT=", ""));
      assert.equal(payload.status, "fail");
      assert.match(payload.summary, /VERCEL_ORG_ID/);
      assert.deepEqual(payload.missingEvidence, ["productionDeployed"]);
    } finally {
      await rm(cwd, { recursive: true, force: true });
    }
  });

  it("can skip deploy when production deploy is explicitly optional", async () => {
    const cwd = await mkdtemp(join(tmpdir(), "kody-vercel-deploy-"));
    try {
      const result = spawnSync("bash", [scriptPath.pathname], {
        cwd,
        env: {
          ...process.env,
          VERCEL_ACCESS_TOKEN: "",
          VERCEL_ORG_ID: "",
          VERCEL_PROJECT_ID: "",
          KODY_CFG_RELEASE_PRODUCTIONDEPLOYREQUIRED: "false",
        },
        encoding: "utf8",
      });

      assert.equal(result.status, 0);
      const line = result.stdout
        .split(/\r?\n/)
        .find((entry) => entry.startsWith("KODY_CAPABILITY_RESULT="));
      assert.ok(line, "skip result side-channel should be emitted");

      const payload = JSON.parse(line.replace("KODY_CAPABILITY_RESULT=", ""));
      assert.equal(payload.status, "pass");
      assert.equal(payload.evidence.productionDeploySkipped, true);
      assert.match(payload.summary, /productionDeployRequired=false/);
    } finally {
      await rm(cwd, { recursive: true, force: true });
    }
  });
});
