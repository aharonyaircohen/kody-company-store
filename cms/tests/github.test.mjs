import { describe, it } from "node:test"
import assert from "node:assert/strict"
import { createGithubCmsAdapter } from "../adapters/github/index.mjs"
import { normalizeCmsConfig } from "../contract/index.mjs"

describe("GitHub CMS adapter", () => {
  it("lists and filters JSON documents from a GitHub-like transport", async () => {
    const adapter = createGithubCmsAdapter({
      config: testConfig(),
      transport: new MemoryTransport({
        "content/articles/one.json": { id: "one", title: "Intro", status: "published" },
        "content/articles/two.json": { id: "two", title: "Draft", status: "draft" },
      }),
    })

    const result = await adapter.list("articles", {
      filters: { status: { equals: "published" } },
    })

    assert.equal(result.total, 1)
    assert.equal(result.docs[0].id, "one")
  })

  it("searches through the same safe filter path as list", async () => {
    const adapter = createGithubCmsAdapter({
      config: testConfig(),
      transport: new MemoryTransport({
        "content/articles/one.json": { id: "one", title: "Intro", status: "published" },
        "content/articles/two.json": { id: "two", title: "Draft", status: "draft" },
      }),
    })

    const result = await adapter.search("articles", {
      filters: { status: { equals: "draft" } },
    })

    assert.equal(result.total, 1)
    assert.equal(result.docs[0].id, "two")
  })

  it("requires approval for create", async () => {
    const transport = new MemoryTransport({})
    const adapter = createGithubCmsAdapter({ config: testConfig({ create: true }), transport })

    await assert.rejects(
      () => adapter.create("articles", { id: "new", title: "New" }),
      /requires approval/,
    )

    const created = await adapter.create(
      "articles",
      { id: "new", title: "New", status: "draft" },
      { approved: true },
    )
    assert.equal(created.id, "new")
  })
})

function testConfig(operations = {}) {
  return normalizeCmsConfig({
    version: 1,
    writePolicy: "approval-required",
    collections: {
      articles: {
        source: { path: "content/articles", idField: "id" },
        operations: { list: true, get: true, ...operations },
        fields: [
          { name: "id", type: "id" },
          { name: "title", type: "text", required: true },
          { name: "status", type: "select", options: ["draft", "published"] },
        ],
        filters: [{ field: "status", operators: ["equals"] }],
      },
    },
  })
}

class MemoryTransport {
  constructor(files) {
    this.files = new Map(
      Object.entries(files).map(([filePath, data]) => [filePath, JSON.stringify(data, null, 2)]),
    )
  }

  listFiles(rootPath) {
    return Promise.resolve([...this.files.keys()].filter((filePath) => filePath.startsWith(`${rootPath}/`)))
  }

  readFile(filePath) {
    if (!this.files.has(filePath)) throw Object.assign(new Error("not found"), { status: 404 })
    return Promise.resolve(this.files.get(filePath))
  }

  writeFile(filePath, content) {
    this.files.set(filePath, content)
    return Promise.resolve()
  }

  deleteFile(filePath) {
    this.files.delete(filePath)
    return Promise.resolve()
  }
}
