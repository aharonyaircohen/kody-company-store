import assert from "node:assert/strict";
import { readdir, readFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { describe, it } from "node:test";

const agentsDir = new URL("../agents/", import.meta.url);

const sharedAgents = [
  "ceo",
  "coo",
  "cto",
  "kody",
  "qa",
  "repo-brain",
  "tech-writer",
  "ux-designer",
];

describe("Store agents", () => {
  it("owns every shared agent identity", async () => {
    const entries = await readdir(agentsDir);
    const slugs = new Set(
      entries.filter((entry) => entry.endsWith(".md")).map((entry) => entry.replace(/\.md$/, "")),
    );

    assert.deepEqual(
      sharedAgents.filter((slug) => !slugs.has(slug)),
      [],
    );
  });

  it("keeps agent files as identities, not jobs", async () => {
    for (const slug of sharedAgents) {
      const path = join(agentsDir.pathname, `${slug}.md`);
      assert.equal(existsSync(path), true, `${slug} must exist`);

      const markdown = await readFile(path, "utf8");
      assert.match(markdown, /^# /, `${slug} must start with a title`);
      assert.match(markdown, /Identity only/i, `${slug} must declare identity-only ownership`);
      assert.doesNotMatch(markdown, /```(?:bash|sh|shell)/i, `${slug} must not embed shell jobs`);
    }
  });
});
