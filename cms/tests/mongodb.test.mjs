import { describe, it } from "node:test"
import assert from "node:assert/strict"
import { createMongoCmsAdapter, buildMongoQuery } from "../adapters/mongodb/index.mjs"
import { normalizeCmsConfig } from "../contract/index.mjs"

describe("Mongo CMS adapter", () => {
  it("builds Mongo queries from generic filters", () => {
    const config = testConfig()
    const query = buildMongoQuery(config.collections.lessons, {
      title: { contains: "intro" },
      status: { in: ["draft", "published"] },
      order: { greater_than_equal: 2 },
    })

    assert.deepEqual(query, {
      title: { $regex: "intro", $options: "i" },
      status: { $in: ["draft", "published"] },
      order: { $gte: 2 },
    })
  })

  it("lists documents through an injected Mongo-like db", async () => {
    const config = testConfig()
    const db = new FakeDb({
      lessons: [
        { _id: "1", title: "B", status: "draft", order: 2 },
        {
          _id: fakeObjectId("2"),
          title: "A",
          status: "published",
          order: 1,
          chapter: fakeObjectId("chapter-1"),
          updatedAt: new Date("2026-06-18T14:16:38.000Z"),
        },
      ],
    })
    const adapter = createMongoCmsAdapter({ config, db })
    const result = await adapter.list("lessons", {
      filters: { status: { equals: "published" } },
      sort: [{ field: "order", direction: "asc" }],
    })

    assert.equal(result.total, 1)
    assert.deepEqual(result.docs[0], {
      _id: "2",
      id: "2",
      title: "A",
      status: "published",
      order: 1,
      chapter: "chapter-1",
      updatedAt: "2026-06-18T14:16:38.000Z",
    })
  })

  it("searches with the same safe filter path as list", async () => {
    const config = testConfig()
    const db = new FakeDb({
      lessons: [
        { _id: "1", title: "Intro", status: "draft", order: 2 },
        { _id: "2", title: "Advanced", status: "published", order: 1 },
      ],
    })
    const adapter = createMongoCmsAdapter({ config, db })
    const result = await adapter.search("lessons", {
      filters: { title: { contains: "intro" } },
    })

    assert.equal(result.total, 1)
    assert.equal(result.docs[0].id, "1")
  })

  it("blocks update without approval", async () => {
    const config = testConfig({ update: true })
    const adapter = createMongoCmsAdapter({ config, db: new FakeDb({ lessons: [] }) })
    await assert.rejects(
      () => adapter.update("lessons", "1", { title: "Changed" }),
      /requires approval/,
    )
  })
})

function testConfig(operations = {}) {
  return normalizeCmsConfig({
    version: 1,
    writePolicy: "approval-required",
    collections: {
      lessons: {
        source: { collection: "lessons", idField: "_id" },
        operations: { list: true, get: true, ...operations },
        fields: [
          { name: "_id", type: "id" },
          { name: "title", type: "text" },
          { name: "status", type: "select", options: ["draft", "published"] },
          { name: "order", type: "number" },
        ],
        filters: [
          { field: "title", operators: ["contains"] },
          { field: "status", operators: ["equals", "in"] },
          { field: "order", operators: ["greater_than_equal"] },
        ],
      },
    },
  })
}

class FakeDb {
  constructor(data) {
    this.data = data
  }

  collection(name) {
    return new FakeCollection(this.data[name] ?? [])
  }
}

class FakeCollection {
  constructor(docs) {
    this.docs = docs
    this.lastQuery = null
  }

  find(query) {
    this.lastQuery = query
    return new FakeCursor(this.docs.filter((doc) => matchesQuery(doc, query)))
  }

  countDocuments(query) {
    return Promise.resolve(this.docs.filter((doc) => matchesQuery(doc, query)).length)
  }

  findOne(query) {
    return Promise.resolve(this.docs.find((doc) => matchesQuery(doc, query)) ?? null)
  }

  updateOne() {
    return Promise.resolve({ matchedCount: 1 })
  }
}

class FakeCursor {
  constructor(docs) {
    this.docs = docs
  }

  sort(sort) {
    const [[field, direction]] = Object.entries(sort)
    this.docs = [...this.docs].sort((a, b) => (a[field] > b[field] ? direction : -direction))
    return this
  }

  skip(offset) {
    this.docs = this.docs.slice(offset)
    return this
  }

  limit(limit) {
    this.docs = this.docs.slice(0, limit)
    return this
  }

  toArray() {
    return Promise.resolve(this.docs)
  }
}

function matchesQuery(doc, query) {
  return Object.entries(query).every(([field, expected]) => {
    if (expected?.$in) return expected.$in.includes(doc[field])
    if (expected?.$gte !== undefined) return doc[field] >= expected.$gte
    if (expected?.$regex) return new RegExp(expected.$regex, expected.$options).test(doc[field])
    return doc[field] === expected
  })
}

function fakeObjectId(value) {
  return { toHexString: () => value }
}
