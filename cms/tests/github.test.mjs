import { describe, it } from "node:test"
import assert from "node:assert/strict"
import {
  adapterName,
  createCmsAdapter,
  createGithubCmsAdapter,
} from "../adapters/github/index.mjs"
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

  it("searches configured text fields", async () => {
    const adapter = createGithubCmsAdapter({
      config: testConfig(),
      transport: new MemoryTransport({
        "content/articles/one.json": { id: "one", title: "Intro to GitHub", status: "published" },
        "content/articles/two.json": { id: "two", title: "Draft", status: "draft" },
      }),
    })

    const result = await adapter.search("articles", {
      search: { query: "github", fields: ["title"] },
    })

    assert.equal(result.total, 1)
    assert.equal(result.docs[0].id, "one")
  })

  it("lists specific ids in requested order", async () => {
    const adapter = createGithubCmsAdapter({
      config: testConfig(),
      transport: new MemoryTransport({
        "content/articles/one.json": { id: "one", title: "One", status: "published" },
        "content/articles/two.json": { id: "two", title: "Two", status: "draft" },
      }),
    })

    const docs = await adapter.listByIds("articles", ["two", "missing", "one"])

    assert.deepEqual(docs.map((doc) => doc.id), ["two", "one"])
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

  it("writes documents to the resolved state repo path and branch", async () => {
    const octokit = new FakeOctokit()
    const adapter = createCmsAdapter({
      config: testConfig({ create: true, get: true }, "enabled"),
      getStateRepository: async () => ({
        octokit,
        owner: "acme",
        repo: "kody-state",
        branch: "kody-state",
        basePath: "A-Guy-Web",
      }),
    })

    const created = await adapter.create("articles", {
      id: "new",
      title: "New",
      status: "draft",
    })

    assert.equal(created.id, "new")
    assert.deepEqual(octokit.writes[0], {
      owner: "acme",
      repo: "kody-state",
      path: "A-Guy-Web/content/articles/new.json",
      branch: "kody-state",
      message: "cms: create articles/new",
      sha: undefined,
      content: Buffer.from(
        JSON.stringify({ id: "new", title: "New", status: "draft" }, null, 2) + "\n",
      ).toString("base64"),
    })
  })

  it("updates and deletes GitHub-backed files safely", async () => {
    const transport = new MemoryTransport({
      "content/articles/one.json": { id: "one", title: "One", status: "draft" },
    })
    const adapter = createGithubCmsAdapter({
      config: testConfig({ update: true, delete: true }, "enabled"),
      transport,
    })

    const updated = await adapter.update("articles", "one", {
      title: "One updated",
      status: "published",
    })
    assert.equal(updated.title, "One updated")
    assert.equal(updated.status, "published")

    assert.equal(await adapter.update("articles", "missing", { title: "Missing" }), null)
    assert.deepEqual(await adapter.delete("articles", "one"), { deleted: true })
    assert.deepEqual(await adapter.delete("articles", "missing"), { deleted: false })
  })

  it("rejects unsafe document ids", async () => {
    const adapter = createGithubCmsAdapter({
      config: testConfig({ create: true }, "enabled"),
      transport: new MemoryTransport({}),
    })

    await assert.rejects(
      () => adapter.create("articles", { id: "../outside", title: "Outside", status: "draft" }),
      /unsafe document id/,
    )
  })

  it("exposes the common Store adapter factory", () => {
    assert.equal(adapterName, "github")
    assert.equal(createCmsAdapter, createGithubCmsAdapter)
  })
})

function testConfig(operations = {}, writePolicy = "approval-required") {
  return normalizeCmsConfig({
    version: 1,
    writePolicy,
    defaultAdapter: "github",
    collections: {
      articles: {
        source: { path: "content/articles", idField: "id" },
        titleField: "title",
        searchFields: ["title"],
        operations: { list: true, get: true, search: true, ...operations },
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
    if (!this.files.has(filePath)) throw Object.assign(new Error("not found"), { status: 404 })
    this.files.delete(filePath)
    return Promise.resolve()
  }
}

class FakeOctokit {
  constructor() {
    this.files = new Map()
    this.writes = []
    this.repos = {
      getContent: async ({ owner, repo, path, ref }) => {
        const key = `${owner}/${repo}/${ref}/${path}`
        if (this.files.has(key)) {
          const file = this.files.get(key)
          return {
            data: {
              type: "file",
              content: file.content,
              encoding: "base64",
              sha: file.sha,
            },
          }
        }
        const prefix = `${key.replace(/\/+$/g, "")}/`
        const entries = [...this.files.keys()]
          .filter((fileKey) => fileKey.startsWith(prefix))
          .map((fileKey) => ({
            type: "file",
            path: fileKey.slice(`${owner}/${repo}/${ref}/`.length),
          }))
        if (entries.length > 0) return { data: entries }
        throw Object.assign(new Error("not found"), { status: 404 })
      },
      createOrUpdateFileContents: async (input) => {
        this.writes.push(input)
        this.files.set(`${input.owner}/${input.repo}/${input.branch}/${input.path}`, {
          content: input.content,
          sha: "sha-next",
        })
        return { data: { content: { sha: "sha-next" } } }
      },
      deleteFile: async (input) => {
        this.files.delete(`${input.owner}/${input.repo}/${input.branch}/${input.path}`)
        return { data: {} }
      },
    }
  }
}
