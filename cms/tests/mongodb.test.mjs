import { describe, it } from "node:test"
import assert from "node:assert/strict"
import {
  buildMongoQuery,
  buildMongoWriteDocument,
  createMongoCmsAdapter,
  normalizeMongoValue,
} from "../adapters/mongodb/index.mjs"
import { normalizeCmsConfig } from "../contract/index.mjs"

describe("Mongo CMS adapter", () => {
  it("normalizes ObjectId-like and Date values recursively", () => {
    const id = new FakeObjectId("64f1a5f6f2a80f3a3a3a3a3a")
    const normalized = normalizeMongoValue({
      _id: id,
      chapter: id,
      updatedAt: new Date("2026-01-02T03:04:05.000Z"),
      nested: [{ id }],
    })

    assert.deepEqual(normalized, {
      _id: "64f1a5f6f2a80f3a3a3a3a3a",
      chapter: "64f1a5f6f2a80f3a3a3a3a3a",
      updatedAt: "2026-01-02T03:04:05.000Z",
      nested: [{ id: "64f1a5f6f2a80f3a3a3a3a3a" }],
    })
  })

  it("builds Mongo queries from generic filters", () => {
    const config = testConfig()
    const query = buildMongoQuery(config.collections.lessons, {
      title: { contains: "intro" },
      status: { in: ["draft", "published"] },
      order: { greater_than_equal: 2 },
      chapter: { equals: "64f1a5f6f2a80f3a3a3a3a3a" },
      isActive: { equals: "true" },
      updatedAt: { greater_than_equal: "2026-01-02T03:04:05.000Z" },
    }, undefined, {
      ObjectId: FakeObjectId,
    })

    assert.deepEqual(query.title, { $regex: "intro", $options: "i" })
    assert.deepEqual(query.status, { $in: ["draft", "published"] })
    assert.deepEqual(query.order, { $gte: 2 })
    assert.ok(query.chapter.$in[0] instanceof FakeObjectId)
    assert.equal(String(query.chapter.$in[0]), "64f1a5f6f2a80f3a3a3a3a3a")
    assert.equal(query.chapter.$in[1], "64f1a5f6f2a80f3a3a3a3a3a")
    assert.equal(query.isActive, true)
    assert.ok(query.updatedAt.$gte instanceof Date)
  })

  it("combines configured filters with text search", () => {
    const config = testConfig()
    const query = buildMongoQuery(
      config.collections.lessons,
      { status: { equals: "published" } },
      { query: "Intro", fields: ["title"] },
    )

    assert.deepEqual(query, {
      $and: [
        { status: "published" },
        { $or: [{ title: { $regex: "Intro", $options: "i" } }] },
      ],
    })
  })

  it("builds typed Mongo write documents from configured writable fields", () => {
    const config = testConfig({ create: true }, "enabled")
    const chapter = "64f1a5f6f2a80f3a3a3a3a3a"
    const payload = buildMongoWriteDocument(
      config.collections.lessons,
      {
        title: "Intro",
        chapter,
        relatedLessons: `${chapter}, ${chapter}`,
        isActive: "true",
        order: "12",
        updatedAt: "2026-01-02T03:04:05.000Z",
      },
      { requireRequiredFields: true, ObjectId: FakeObjectId },
    )

    assert.equal(payload.title, "Intro")
    assert.ok(payload.chapter instanceof FakeObjectId)
    assert.equal(String(payload.chapter), chapter)
    assert.equal(payload.isActive, true)
    assert.equal(payload.order, 12)
    assert.ok(payload.updatedAt instanceof Date)
    assert.equal(payload.relatedLessons.length, 2)
    assert.ok(payload.relatedLessons[0] instanceof FakeObjectId)
  })

  it("rejects writes that fail configured field validation", () => {
    const config = testConfig({ create: true }, "enabled")

    assert.throws(
      () =>
        buildMongoWriteDocument(
          config.collections.lessons,
          {
            title: "No",
            status: "draft",
            order: 50,
          },
          { requireRequiredFields: true },
        ),
      /Title must be at least 3 characters/,
    )
    assert.throws(
      () =>
        buildMongoWriteDocument(
          config.collections.lessons,
          {
            title: "Valid title",
            status: "archived",
            order: 50,
          },
          { requireRequiredFields: true },
        ),
      /Status must be one of: draft, published/,
    )
    assert.throws(
      () =>
        buildMongoWriteDocument(
          config.collections.lessons,
          {
            title: "Valid title",
            status: "draft",
            order: 101,
          },
          { requireRequiredFields: true },
        ),
      /Order must be at most 100/,
    )
  })

  it("skips optional blank values before coercion", () => {
    const config = testConfig({ update: true }, "enabled")
    const payload = buildMongoWriteDocument(
      config.collections.lessons,
      {
        status: "",
        order: "",
        relatedLessons: [],
      },
      { requireRequiredFields: false },
    )

    assert.deepEqual(payload, {})
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

  it("uses an injected Mongo-like client without requiring a uri", async () => {
    const config = testConfig()
    const db = new FakeDb({ lessons: [] })
    const client = {
      closeCalled: false,
      db(databaseName) {
        assert.equal(databaseName, "A-Guy-Dev")
        return db
      },
      close() {
        this.closeCalled = true
        return Promise.resolve()
      },
    }
    const adapter = createMongoCmsAdapter({
      config,
      client,
      databaseName: "A-Guy-Dev",
    })

    const result = await adapter.list("lessons")
    await adapter.close()

    assert.equal(result.total, 0)
    assert.equal(client.closeCalled, false)
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

function testConfig(operations = {}, writePolicy = "approval-required") {
  return normalizeCmsConfig({
    version: 1,
    writePolicy,
    collections: {
      lessons: {
        source: { collection: "lessons", idField: "_id" },
        searchFields: ["title"],
        operations: { list: true, get: true, search: true, ...operations },
        fields: [
          { name: "_id", type: "id" },
          {
            name: "title",
            type: "text",
            required: true,
            validation: { minLength: 3 },
          },
          { name: "status", type: "select", options: ["draft", "published"] },
          { name: "order", type: "number", validation: { min: 0, max: 100 } },
          { name: "chapter", type: "relation", target: "chapters" },
          { name: "relatedLessons", type: "relationMany", target: "lessons" },
          { name: "isActive", type: "boolean" },
          { name: "updatedAt", type: "date" },
        ],
        filters: [
          { field: "title", operators: ["contains"] },
          { field: "status", operators: ["equals", "in"] },
          { field: "order", operators: ["greater_than_equal"] },
          { field: "chapter", operators: ["equals"] },
          { field: "isActive", operators: ["equals"] },
          { field: "updatedAt", operators: ["greater_than_equal"] },
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

  insertOne(doc) {
    const insertedId = doc._id ?? "inserted-id"
    this.docs.push({ ...doc, _id: insertedId })
    return Promise.resolve({ insertedId })
  }

  deleteOne(query) {
    const index = this.docs.findIndex((doc) => matchesQuery(doc, query))
    if (index === -1) return Promise.resolve({ deletedCount: 0 })
    this.docs.splice(index, 1)
    return Promise.resolve({ deletedCount: 1 })
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
  if (query.$and) return query.$and.every((entry) => matchesQuery(doc, entry))
  if (query.$or) return query.$or.some((entry) => matchesQuery(doc, entry))
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

class FakeObjectId {
  constructor(value) {
    this.value = value
  }

  toHexString() {
    return this.value
  }

  toString() {
    return this.value
  }
}
