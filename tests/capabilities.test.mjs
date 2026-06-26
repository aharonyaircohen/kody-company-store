import assert from "node:assert/strict";
import { readdir, readFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { describe, it } from "node:test";

const manifestPath = new URL("../kody-store.json", import.meta.url);
const capabilitiesDir = new URL("../.kody/capabilities/", import.meta.url);

describe("Store capabilities", () => {
  it("declares capabilities as a first-class asset root", async () => {
    const manifest = JSON.parse(await readFile(manifestPath, "utf8"));

    assert.equal(manifest.assetRoots.capabilities, ".kody/capabilities");
  });

  it("contains migrated capability folders with profile and capability body", async () => {
    assert.equal(existsSync(capabilitiesDir), true, ".kody/capabilities must exist");

    const entries = await readdir(capabilitiesDir, { withFileTypes: true });
    const slugs = entries.filter((entry) => entry.isDirectory()).map((entry) => entry.name);

    assert.ok(slugs.length > 0, "capability catalog must not be empty");
    for (const slug of slugs) {
      const dir = join(capabilitiesDir.pathname, slug);
      assert.equal(existsSync(join(dir, "profile.json")), true, `${slug} must include profile.json`);
      assert.equal(existsSync(join(dir, "capability.md")), true, `${slug} must include capability.md`);
    }
  });

  it("keeps legacy roots as temporary compatibility mirrors only", async () => {
    const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
    const roots = manifest.assetRoots;

    assert.equal(roots["agent-responsibilities"], ".kody/agent-responsibilities");
    assert.equal(roots["agent-actions"], ".kody/agent-actions");
    assert.equal(existsSync(new URL("../.kody/agent-responsibilities/", import.meta.url)), true);
    assert.equal(existsSync(new URL("../.kody/agent-actions/", import.meta.url)), true);
  });
});
