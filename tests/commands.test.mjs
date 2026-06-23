import assert from "node:assert/strict";
import { readdir, readFile } from "node:fs/promises";
import { join } from "node:path";
import { describe, it } from "node:test";

const commandDir = new URL("../.kody/commands/", import.meta.url);

const sharedCommands = [
  "agentResponsibility",
  "analyze",
  "briefing",
  "explain",
  "factory",
  "goal",
  "init",
  "issue",
  "mission",
  "plan",
  "research",
  "review",
];

function parseFrontmatter(markdown) {
  const match = /^---\r?\n([\s\S]*?)\r?\n---\r?\n?/.exec(markdown);
  assert.ok(match, "command file must start with frontmatter");

  const fields = new Map();
  for (const line of match[1].split(/\r?\n/)) {
    const index = line.indexOf(":");
    if (index < 0) continue;
    fields.set(line.slice(0, index).trim(), line.slice(index + 1).trim());
  }
  return fields;
}

describe("Store commands", () => {
  it("owns every shared Dashboard command", async () => {
    const entries = await readdir(commandDir);
    const slugs = new Set(
      entries.filter((entry) => entry.endsWith(".md")).map((entry) => entry.replace(/\.md$/, "")),
    );

    assert.deepEqual(
      sharedCommands.filter((slug) => !slugs.has(slug)),
      [],
    );
  });

  it("declares menu metadata for every command", async () => {
    for (const slug of sharedCommands) {
      const markdown = await readFile(join(commandDir.pathname, `${slug}.md`), "utf8");
      const fields = parseFrontmatter(markdown);
      assert.ok(fields.get("description"), `${slug} must declare description`);
    }
  });
});
