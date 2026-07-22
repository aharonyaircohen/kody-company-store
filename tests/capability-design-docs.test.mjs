import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { describe, it } from "node:test";

describe("capability design documentation", () => {
  it("defines reusable action and anti-duplication boundaries", async () => {
    const docs = await readFile(
      new URL("../docs/capability-design.md", import.meta.url),
      "utf8",
    );

    assert.match(docs, /Capabilities are reusable actions/);
    assert.match(docs, /Goal\s+= why/);
    assert.match(docs, /Loop\s+= when/);
    assert.match(docs, /Workflow\s+= which actions/);
    assert.match(docs, /build-knowledge-graph/);
    assert.match(docs, /Do not copy its scripts/);
    assert.match(docs, /wrapper capability.*workflow/is);
  });
});
