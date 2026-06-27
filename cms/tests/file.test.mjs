import { describe, it } from "node:test"
import assert from "node:assert/strict"
import { mkdtemp, readFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import path from "node:path"

import {
  adapterName,
  createCmsAdapter,
  createFileCmsAdapter,
} from "../adapters/file/index.mjs"
import { normalizeCmsConfig } from "../contract/index.mjs"

describe("File CMS adapter", () => {
  it("creates collection folders and JSON files from the CMS schema", async () => {
    const rootDir = await tempRoot()
    const adapter = createFileCmsAdapter({
      config: testConfig({ create: true, get: true }, "enabled"),
      rootDir,
    })

    const created = await adapter.create("articles", {
      id: "intro",
      title: "Intro",
      status: "published",
      order: 2,
      tags: ["cms"],
    })

    const filePath = path.join(rootDir, "content/articles/intro.json")
    const file = JSON.parse(await readFile(filePath, "utf8"))
    assert.equal(created.id, "intro")
    assert.deepEqual(file, {
      id: "intro",
      title: "Intro",
      status: "published",
      order: 2,
      tags: ["cms"],
    })
  })

  it("lists, filters, searches, sorts, and paginates file-backed documents", async () => {
    const rootDir = await tempRoot()
    const adapter = createFileCmsAdapter({
      config: testConfig({ create: true }, "enabled"),
      rootDir,
    })
    await adapter.create("articles", {
      id: "draft",
      title: "Draft note",
      status: "draft",
      order: 3,
      tags: ["cms"],
    })
    await adapter.create("articles", {
      id: "intro",
      title: "Intro to files",
      status: "published",
      order: 2,
      tags: ["cms", "file"],
    })
    await adapter.create("articles", {
      id: "deep",
      title: "Deep file schema",
      status: "published",
      order: 1,
      tags: ["file"],
    })

    const result = await adapter.list("articles", {
      filters: { status: { equals: "published" } },
      search: { query: "file", fields: ["title"] },
      sort: [{ field: "order", direction: "asc" }],
      limit: 1,
      offset: 1,
    })

    assert.equal(result.total, 2)
    assert.equal(result.limit, 1)
    assert.equal(result.offset, 1)
    assert.deepEqual(result.docs.map((doc) => doc.id), ["intro"])
  })

  it("reads specific ids, updates documents, and deletes files", async () => {
    const rootDir = await tempRoot()
    const adapter = createFileCmsAdapter({
      config: testConfig({ create: true, update: true, delete: true }, "enabled"),
      rootDir,
    })
    await adapter.create("articles", {
      id: "one",
      title: "One",
      status: "draft",
      order: 1,
      tags: [],
    })
    await adapter.create("articles", {
      id: "two",
      title: "Two",
      status: "draft",
      order: 2,
      tags: [],
    })

    const docs = await adapter.listByIds("articles", ["two", "missing", "one"])
    assert.deepEqual(docs.map((doc) => doc.id), ["two", "one"])

    const updated = await adapter.update("articles", "one", {
      title: "One updated",
      status: "published",
    })
    assert.equal(updated.title, "One updated")
    assert.equal(updated.status, "published")

    assert.deepEqual(await adapter.delete("articles", "one"), { deleted: true })
    assert.equal(await adapter.get("articles", "one"), null)
    assert.deepEqual(await adapter.delete("articles", "missing"), { deleted: false })
  })

  it("validates writes and write policy", async () => {
    const rootDir = await tempRoot()
    const approvalAdapter = createFileCmsAdapter({
      config: testConfig({ create: true }),
      rootDir,
    })

    await assert.rejects(
      () =>
        approvalAdapter.create("articles", {
          id: "blocked",
          title: "Blocked",
          status: "draft",
          order: 1,
          tags: [],
        }),
      /requires approval/,
    )

    const enabledAdapter = createFileCmsAdapter({
      config: testConfig({ create: true }, "enabled"),
      rootDir,
    })
    await assert.rejects(
      () =>
        enabledAdapter.create("articles", {
          id: "invalid",
          title: "Invalid",
          status: "archived",
          order: 1,
          tags: [],
        }),
      /status must be one of its options/,
    )
  })

  it("rejects unsafe document ids", async () => {
    const adapter = createCmsAdapter({
      config: testConfig({ create: true }, "enabled"),
      rootDir: await tempRoot(),
    })

    await assert.rejects(
      () =>
        adapter.create("articles", {
          id: "../outside",
          title: "Outside",
          status: "draft",
          order: 1,
          tags: [],
        }),
      /unsafe document id/,
    )
  })

  it("exposes the common Store adapter factory", () => {
    assert.equal(adapterName, "file")
    assert.equal(createCmsAdapter, createFileCmsAdapter)
  })
})

async function tempRoot() {
  return mkdtemp(path.join(tmpdir(), "kody-file-cms-"))
}

function testConfig(operations = {}, writePolicy = "approval-required") {
  return normalizeCmsConfig({
    version: 1,
    defaultAdapter: "file",
    writePolicy,
    collections: {
      articles: {
        source: {
          path: "content/articles",
          extension: "json",
          idField: "id",
        },
        titleField: "title",
        searchFields: ["title"],
        operations: {
          list: true,
          get: true,
          search: true,
          ...operations,
        },
        defaultSort: [{ field: "order", direction: "asc" }],
        fields: [
          { name: "id", type: "id" },
          { name: "title", type: "text", required: true },
          { name: "status", type: "select", options: ["draft", "published"] },
          { name: "order", type: "number" },
          { name: "tags", type: "multiSelect", options: ["cms", "file"] },
        ],
        filters: [
          { field: "status", operators: ["equals"] },
          { field: "tags", operators: ["contains"] },
        ],
      },
    },
  })
}
