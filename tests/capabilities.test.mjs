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

  it("does not expose legacy action or removed capability roots", async () => {
    const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
    const roots = manifest.assetRoots;
    const removedCapabilityRoot = ["agent", "respon", "sibilities"].join("-");
    const oldActionsRoot = ["agent", "actions"].join("-");

    assert.equal(roots[removedCapabilityRoot], undefined);
    assert.equal(roots[oldActionsRoot], undefined);
    assert.equal(existsSync(new URL(`../.kody/${removedCapabilityRoot}/`, import.meta.url)), false);
    assert.equal(existsSync(new URL(`../.kody/${oldActionsRoot}/`, import.meta.url)), false);
  });
});
