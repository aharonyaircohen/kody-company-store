import { describe, it } from "node:test"
import assert from "node:assert/strict"
import path from "node:path"
import { fileURLToPath } from "node:url"
import {
  CmsConfigError,
  assertOperationAllowed,
  listGeneratedOperations,
  normalizeCmsConfig,
  validateDocument,
} from "../contract/index.mjs"
import { loadCmsConfigFromDir } from "../contract/files.mjs"

const dirname = path.dirname(fileURLToPath(import.meta.url))
const exampleRoot = path.resolve(dirname, "../examples/kody-state/A-Guy-Admin/cms")

describe("CMS contract", () => {
  it("loads state-repo style config", async () => {
    const config = await loadCmsConfigFromDir(exampleRoot)
    assert.equal(config.version, 1)
    assert.equal(config.environment, "dev")
    assert.equal(config.defaultAdapter, "mongodb")
    assert.equal(config.collections.lessons.source.collection, "lessons")
    assert.equal(config.collections.lessons.writePolicy, "read-only")
  })

  it("generates operation names from config", async () => {
    const config = await loadCmsConfigFromDir(exampleRoot)
    const names = listGeneratedOperations(config).map((operation) => operation.name)
    assert.deepEqual(names, ["cms_list_lessons", "cms_get_lesson", "cms_search_lesson"])
  })

  it("validates select, multi-select, and relation fields generically", () => {
    const config = normalizeCmsConfig({
      version: 1,
      collections: {
        articles: {
          fields: [
            { name: "title", type: "text", required: true },
            { name: "status", type: "select", options: ["draft", "published"] },
            { name: "tags", type: "multiSelect", options: ["math", "physics"] },
            { name: "chapter", type: "relation", target: "chapters" },
          ],
        },
      },
    })

    const result = validateDocument(config.collections.articles, {
      title: "Intro",
      status: "published",
      tags: ["math"],
      chapter: "chapter-1",
    })

    assert.equal(result.ok, true)
  })

  it("blocks writes unless approved", async () => {
    const config = normalizeCmsConfig({
      version: 1,
      writePolicy: "approval-required",
      collections: {
        lessons: {
          operations: { update: true },
          fields: [{ name: "title", type: "text" }],
        },
      },
    })

    assert.throws(
      () => assertOperationAllowed(config, "lessons", "update"),
      CmsConfigError,
    )
    assert.equal(assertOperationAllowed(config, "lessons", "update", { approved: true }), true)
  })
})

