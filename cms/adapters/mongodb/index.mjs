import {
  CmsConfigError,
  assertOperationAllowed,
  getCollection,
  getCollectionIdField,
  normalizeFilters,
  validateDocument,
} from "../../contract/index.mjs"

export function createMongoCmsAdapter(options) {
  const { config, approved = false } = options
  let client = options.client
  let ownsClient = false

  async function getDb() {
    if (options.db) return options.db
    if (!client) {
      const MongoClient = options.MongoClient ?? (await import("mongodb")).MongoClient
      if (!options.uri) throw new CmsConfigError(["Mongo adapter requires uri or client"])
      client = new MongoClient(options.uri)
      await client.connect()
      ownsClient = true
    }
    const databaseName =
      options.databaseName ??
      config.adapters?.mongodb?.databaseName ??
      config.adapters?.["store:cms-mongodb"]?.databaseName
    if (!databaseName) throw new CmsConfigError(["Mongo adapter requires databaseName"])
    return client.db(databaseName)
  }

  async function getMongoCollection(collectionName) {
    const db = await getDb()
    const collection = getCollection(config, collectionName)
    return {
      meta: collection,
      mongo: db.collection(collection.source.collection ?? collection.name),
    }
  }

  return {
    async close() {
      if (ownsClient && client) await client.close()
    },

    async list(collectionName, query = {}) {
      assertOperationAllowed(config, collectionName, "list")
      const { meta, mongo } = await getMongoCollection(collectionName)
      const filter = buildMongoQuery(meta, query.filters ?? {})
      const limit = clampLimit(query.limit)
      const offset = Math.max(0, Number(query.offset ?? 0))
      const sort = buildMongoSort(query.sort ?? meta.defaultSort)
      const projection = buildProjection(meta, query.fields)

      const cursor = mongo.find(filter, projection ? { projection } : undefined)
      if (sort) cursor.sort(sort)
      cursor.skip(offset).limit(limit)

      const [docs, total] = await Promise.all([
        cursor.toArray(),
        mongo.countDocuments(filter),
      ])

      return {
        docs: docs.map((doc) => normalizeMongoDocument(doc, meta)),
        total,
        limit,
        offset,
      }
    },

    async search(collectionName, query = {}) {
      assertOperationAllowed(config, collectionName, "search")
      return this.list(collectionName, query)
    },

    async get(collectionName, id) {
      assertOperationAllowed(config, collectionName, "get")
      const { meta, mongo } = await getMongoCollection(collectionName)
      const doc = await mongo.findOne({ [getCollectionIdField(meta)]: coerceId(id, options) })
      return doc ? normalizeMongoDocument(doc, meta) : null
    },

    async create(collectionName, data, operationOptions = {}) {
      assertOperationAllowed(config, collectionName, "create", {
        approved: operationOptions.approved ?? approved,
      })
      const { meta, mongo } = await getMongoCollection(collectionName)
      const validation = validateDocument(meta, data)
      if (!validation.ok) throw new CmsConfigError(validation.errors)
      const result = await mongo.insertOne(validation.value)
      return this.get(collectionName, String(result.insertedId))
    },

    async update(collectionName, id, data, operationOptions = {}) {
      assertOperationAllowed(config, collectionName, "update", {
        approved: operationOptions.approved ?? approved,
      })
      const { meta, mongo } = await getMongoCollection(collectionName)
      const validation = validateDocument(meta, data, { partial: true })
      if (!validation.ok) throw new CmsConfigError(validation.errors)
      await mongo.updateOne(
        { [getCollectionIdField(meta)]: coerceId(id, options) },
        { $set: validation.value },
      )
      return this.get(collectionName, id)
    },

    async delete(collectionName, id, operationOptions = {}) {
      assertOperationAllowed(config, collectionName, "delete", {
        approved: operationOptions.approved ?? approved,
      })
      const { meta, mongo } = await getMongoCollection(collectionName)
      const result = await mongo.deleteOne({ [getCollectionIdField(meta)]: coerceId(id, options) })
      return { deleted: result.deletedCount === 1 }
    },
  }
}

export function buildMongoQuery(collection, filters = {}) {
  const normalized = normalizeFilters(collection, filters)
  const query = {}
  for (const [field, operators] of Object.entries(normalized)) {
    for (const [operator, value] of Object.entries(operators)) {
      if (operator === "equals") query[field] = value
      if (operator === "not_equals") query[field] = { ...asObject(query[field]), $ne: value }
      if (operator === "contains") query[field] = { $regex: escapeRegex(String(value)), $options: "i" }
      if (operator === "in") query[field] = { $in: value }
      if (operator === "exists") query[field] = { $exists: Boolean(value) }
      if (operator === "greater_than") query[field] = { ...asObject(query[field]), $gt: value }
      if (operator === "greater_than_equal") query[field] = { ...asObject(query[field]), $gte: value }
      if (operator === "less_than") query[field] = { ...asObject(query[field]), $lt: value }
      if (operator === "less_than_equal") query[field] = { ...asObject(query[field]), $lte: value }
    }
  }
  return query
}

function normalizeMongoDocument(doc, collection) {
  const idField = getCollectionIdField(collection)
  const normalized = { ...doc }
  if (normalized[idField] !== undefined) normalized[idField] = String(normalized[idField])
  if (idField !== "id" && normalized.id === undefined && normalized[idField] !== undefined) {
    normalized.id = String(normalized[idField])
  }
  return normalized
}

function buildMongoSort(sort = []) {
  const entries = Array.isArray(sort) ? sort : []
  if (entries.length === 0) return null
  return Object.fromEntries(
    entries.map((entry) => {
      if (typeof entry === "string") return [entry.replace(/^-/, ""), entry.startsWith("-") ? -1 : 1]
      return [entry.field, entry.direction === "desc" ? -1 : 1]
    }),
  )
}

function buildProjection(collection, fields) {
  const allowed = new Set((collection.fields ?? []).map((field) => field.name))
  const requested = Array.isArray(fields) ? fields.filter((field) => allowed.has(field)) : []
  if (requested.length === 0) return null
  return Object.fromEntries(requested.map((field) => [field, 1]))
}

function coerceId(id, options) {
  if (options.ObjectId && typeof id === "string" && /^[a-f0-9]{24}$/i.test(id)) {
    return new options.ObjectId(id)
  }
  return id
}

function clampLimit(limit) {
  const numeric = Number(limit ?? 50)
  if (!Number.isFinite(numeric)) return 50
  return Math.max(1, Math.min(100, numeric))
}

function asObject(value) {
  return value && typeof value === "object" && !Array.isArray(value) ? value : {}
}

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
}
