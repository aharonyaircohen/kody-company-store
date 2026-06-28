import { createHash } from "node:crypto"

import {
  CmsConfigError,
  assertOperationAllowed,
  getCollection,
  getCollectionIdField,
  normalizeFilters,
} from "../../contract/index.mjs"

export const adapterName = "mongodb"
export const createCmsAdapter = createMongoCmsAdapter

const clientCache = new Map()

export function createMongoCmsAdapter(options) {
  const { config, approved = false } = options

  return {
    async close() {
      if (options.closeClient === true && options.client?.close) await options.client.close()
    },

    async list(collectionName, query = {}) {
      assertOperationAllowed(config, collectionName, "list")
      const collection = getCollection(config, collectionName)
      return listMongoDocuments({ ...options, collection, query })
    },

    async listByIds(collectionName, ids = []) {
      assertOperationAllowed(config, collectionName, "list")
      const collection = getCollection(config, collectionName)
      return listMongoDocumentsByIds({ ...options, collection, ids })
    },

    async search(collectionName, query = {}) {
      assertOperationAllowed(config, collectionName, "search")
      const collection = getCollection(config, collectionName)
      return listMongoDocuments({ ...options, collection, query })
    },

    async get(collectionName, id) {
      assertOperationAllowed(config, collectionName, "get")
      const collection = getCollection(config, collectionName)
      return getMongoDocument({ ...options, collection, id })
    },

    async create(collectionName, data, operationOptions = {}) {
      assertOperationAllowed(config, collectionName, "create", {
        approved: operationOptions.approved ?? approved,
      })
      const collection = getCollection(config, collectionName)
      return createMongoDocument({ ...options, collection, data })
    },

    async update(collectionName, id, data, operationOptions = {}) {
      assertOperationAllowed(config, collectionName, "update", {
        approved: operationOptions.approved ?? approved,
      })
      const collection = getCollection(config, collectionName)
      return updateMongoDocument({ ...options, collection, id, data })
    },

    async delete(collectionName, id, operationOptions = {}) {
      assertOperationAllowed(config, collectionName, "delete", {
        approved: operationOptions.approved ?? approved,
      })
      const collection = getCollection(config, collectionName)
      const deleted = await deleteMongoDocument({ ...options, collection, id })
      return { deleted }
    },
  }
}

export async function listMongoDocuments(options) {
  const runtime = await getMongoRuntime(options)
  const filter = buildMongoQuery(
    options.collection,
    options.query.filters ?? {},
    options.query.search,
    runtime,
  )
  const limit = clampLimit(options.query.limit)
  const offset = Math.max(0, Number(options.query.offset ?? 0))
  const sort = buildMongoSort(options.query.sort ?? options.collection.defaultSort)
  const projection = buildProjection(options.collection, options.query.fields)
  const cursor = runtime.mongoCollection.find(filter, { projection })

  if (sort) cursor.sort(sort)
  cursor.skip(offset).limit(limit)

  const [docs, total] = await Promise.all([
    cursor.toArray(),
    runtime.mongoCollection.countDocuments(filter),
  ])

  return {
    docs: docs.map((doc) => normalizeMongoDocument(doc, options.collection)),
    total,
    limit,
    offset,
  }
}

export async function listMongoDocumentsByIds(options) {
  const runtime = await getMongoRuntime(options)
  const idsQuery = buildIdsQuery(options.collection, options.ids, runtime)
  const projection = buildProjection(options.collection)
  const docs = await runtime.mongoCollection.find(idsQuery, { projection }).toArray()
  return docs.map((doc) => normalizeMongoDocument(doc, options.collection))
}

export async function getMongoDocument(options) {
  const runtime = await getMongoRuntime(options)
  const doc = await runtime.mongoCollection.findOne(
    buildIdQuery(options.collection, options.id, runtime),
    { projection: buildProjection(options.collection) },
  )
  return doc ? normalizeMongoDocument(doc, options.collection) : null
}

export async function createMongoDocument(options) {
  const runtime = await getMongoRuntime(options)
  const payload = buildMongoWriteDocument(options.collection, options.data, {
    requireRequiredFields: true,
    ObjectId: runtime.ObjectId,
  })
  const result = await runtime.mongoCollection.insertOne(payload)
  const created = await runtime.mongoCollection.findOne(
    { _id: result.insertedId },
    { projection: buildProjection(options.collection) },
  )
  return normalizeMongoDocument(
    created ?? { ...payload, _id: result.insertedId },
    options.collection,
  )
}

export async function updateMongoDocument(options) {
  const runtime = await getMongoRuntime(options)
  const payload = buildMongoWriteDocument(options.collection, options.data, {
    requireRequiredFields: false,
    ObjectId: runtime.ObjectId,
  })
  const filter = buildIdQuery(options.collection, options.id, runtime)

  if (Object.keys(payload).length > 0) {
    await runtime.mongoCollection.updateOne(filter, { $set: payload })
  }

  const updated = await runtime.mongoCollection.findOne(filter, {
    projection: buildProjection(options.collection),
  })
  return updated ? normalizeMongoDocument(updated, options.collection) : null
}

export async function deleteMongoDocument(options) {
  const runtime = await getMongoRuntime(options)
  const result = await runtime.mongoCollection.deleteOne(
    buildIdQuery(options.collection, options.id, runtime),
  )
  return result.deletedCount > 0
}

export function buildMongoQuery(collection, filters = {}, search, options = {}) {
  const normalized = normalizeFilters(collection, filters)
  const query = {}
  const fields = new Map((collection.fields ?? []).map((field) => [field.name, field]))

  for (const [fieldName, operators] of Object.entries(normalized)) {
    const field = fields.get(fieldName)
    if (!field) continue

    for (const [operator, rawValue] of Object.entries(operators)) {
      const value = coerceMongoValue(field, rawValue, options)
      if (operator === "equals") {
        query[fieldName] = coerceMongoEqualityValue(field, rawValue, options)
      }
      if (operator === "not_equals") {
        query[fieldName] = { ...asObject(query[fieldName]), $ne: value }
      }
      if (operator === "contains") {
        query[fieldName] = {
          $regex: escapeRegex(String(rawValue ?? "")),
          $options: "i",
        }
      }
      if (operator === "in") {
        query[fieldName] = { $in: coerceMongoInValues(field, rawValue, options) }
      }
      if (operator === "exists") {
        query[fieldName] = { $exists: Boolean(value) }
      }
      if (operator === "greater_than") {
        query[fieldName] = { ...asObject(query[fieldName]), $gt: value }
      }
      if (operator === "greater_than_equal") {
        query[fieldName] = { ...asObject(query[fieldName]), $gte: value }
      }
      if (operator === "less_than") {
        query[fieldName] = { ...asObject(query[fieldName]), $lt: value }
      }
      if (operator === "less_than_equal") {
        query[fieldName] = { ...asObject(query[fieldName]), $lte: value }
      }
    }
  }

  const searchQuery = buildMongoSearchQuery(collection, search)
  if (!searchQuery) return query
  if (Object.keys(query).length === 0) return searchQuery
  return { $and: [query, searchQuery] }
}

export function buildMongoWriteDocument(
  collection,
  value,
  options = { requireRequiredFields: false },
) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new CmsConfigError(["CMS document body must be an object."])
  }

  const idField = getCollectionIdField(collection)
  const fieldsByName = new Map((collection.fields ?? []).map((field) => [field.name, field]))
  const writableFields = (collection.fields ?? []).filter(
    (field) =>
      !field.hidden &&
      !field.readOnly &&
      field.type !== "id" &&
      field.name !== idField,
  )
  const writableNames = new Set(writableFields.map((field) => field.name))
  const payload = {}

  for (const key of Object.keys(value)) {
    const field = fieldsByName.get(key)
    if (!field || !writableNames.has(key)) {
      throw new CmsConfigError([`field is not writable: ${key}`])
    }
  }

  for (const field of writableFields) {
    const rawValue = value[field.name]
    if (rawValue === undefined) {
      if (options.requireRequiredFields && field.required) {
        throw new CmsConfigError([`missing required field: ${field.name}`])
      }
      continue
    }

    const validationIssue = getFieldValidationIssue(field, rawValue)
    if (validationIssue) throw new CmsConfigError([validationIssue])
    if (!field.required && isBlankValue(rawValue)) continue

    payload[field.name] = coerceMongoValue(field, rawValue, options)
  }

  return payload
}

export function normalizeMongoValue(value) {
  if (value === null || value === undefined) return value
  if (value instanceof Date) return value.toISOString()
  if (isObjectIdLike(value)) return value.toHexString()
  if (Array.isArray(value)) return value.map((item) => normalizeMongoValue(item))
  if (typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value).map(([key, child]) => [key, normalizeMongoValue(child)]),
    )
  }
  return value
}

export function getMongoDatabase(client, databaseName) {
  return databaseName ? client.db(databaseName) : client.db()
}

async function getMongoRuntime(options) {
  const collectionName = options.collection.source?.collection ?? options.collection.name
  if (options.db) {
    return {
      mongoCollection: options.db.collection(collectionName),
      ObjectId: options.ObjectId,
    }
  }

  const settings = getMongoSettings(options)
  const databaseName = resolveMongoDatabaseName(options, settings)
  if (options.client) {
    return {
      mongoCollection: getMongoDatabase(options.client, databaseName).collection(collectionName),
      ObjectId: options.ObjectId,
    }
  }

  const uri = await resolveMongoUri(options, settings)
  const driver = await getMongoDriver(options)
  const client = await getMongoClient(uri, driver.MongoClient)

  return {
    mongoCollection: getMongoDatabase(client, databaseName).collection(collectionName),
    ObjectId: driver.ObjectId,
  }
}

function resolveMongoDatabaseName(options, settings) {
  return (
    stringValue(options.databaseName) ??
    stringValue(settings.databaseName) ??
    stringValue(options.config?.adapters?.mongodb?.databaseName) ??
    stringValue(options.config?.adapters?.["store:cms-mongodb"]?.databaseName)
  )
}

async function resolveMongoUri(options, settings) {
  if (options.uri) return options.uri
  const databaseUriSecret =
    stringValue(options.databaseUriSecret) ??
    stringValue(settings.databaseUriSecret) ??
    stringValue(options.config?.adapters?.mongodb?.databaseUriSecret) ??
    stringValue(options.config?.adapters?.["store:cms-mongodb"]?.databaseUriSecret)

  if (!databaseUriSecret) {
    throw new CmsConfigError(["Mongo adapter requires databaseUriSecret or uri"])
  }
  if (typeof options.getSecret !== "function") {
    throw new CmsConfigError(["Mongo adapter requires getSecret for databaseUriSecret"])
  }

  const uri = await options.getSecret(databaseUriSecret)
  if (!uri) throw new CmsConfigError([`Secret "${databaseUriSecret}" not configured`])
  return uri
}

function getMongoSettings(options) {
  if (options.settings && typeof options.settings === "object") return options.settings
  return {}
}

async function getMongoDriver(options) {
  if (options.MongoClient && options.ObjectId) {
    return { MongoClient: options.MongoClient, ObjectId: options.ObjectId }
  }
  const driver = await import("mongodb")
  return {
    MongoClient: options.MongoClient ?? driver.MongoClient,
    ObjectId: options.ObjectId ?? driver.ObjectId,
  }
}

async function getMongoClient(uri, MongoClient) {
  const key = createHash("sha256").update(uri).digest("hex")
  let clientPromise = clientCache.get(key)

  if (!clientPromise) {
    clientPromise = new MongoClient(uri).connect()
    clientCache.set(key, clientPromise)
  }

  return clientPromise
}

function normalizeMongoDocument(doc, collection) {
  const normalized = normalizeMongoValue(doc)
  const idField = getCollectionIdField(collection)
  if (idField !== "id" && normalized.id === undefined && normalized[idField] != null) {
    normalized.id = normalized[idField]
  }
  return normalized
}

function buildMongoSearchQuery(collection, search) {
  const query = search?.query?.trim()
  if (!query) return null
  const fields = search?.fields?.length ? search.fields : collection.searchFields ?? []
  if (fields.length === 0) return null
  return {
    $or: fields.map((field) => ({
      [field]: { $regex: escapeRegex(query), $options: "i" },
    })),
  }
}

function buildIdQuery(collection, id, options = {}) {
  const idField = getCollectionIdField(collection)
  const value = buildIdValue(id, options)
  if (idField !== "_id") {
    return { $or: [{ [idField]: value }, { _id: value }] }
  }
  return { [idField]: value }
}

function buildIdValue(id, options = {}) {
  if (options.ObjectId && isObjectIdString(id)) {
    return { $in: [new options.ObjectId(id), id] }
  }
  return id
}

function buildIdsQuery(collection, ids, options = {}) {
  const idField = getCollectionIdField(collection)
  const values = []
  for (const id of ids) {
    if (options.ObjectId && isObjectIdString(id)) {
      values.push(new options.ObjectId(id), id)
    } else {
      values.push(id)
    }
  }
  const value = { $in: values }
  if (idField !== "_id") {
    return { $or: [{ [idField]: value }, { _id: value }] }
  }
  return { [idField]: value }
}

function buildMongoSort(sortEntries = []) {
  const entries = Array.isArray(sortEntries) ? sortEntries : []
  if (entries.length === 0) return undefined
  return Object.fromEntries(
    entries.map((entry) => {
      if (typeof entry === "string") {
        return [entry.replace(/^-/, ""), entry.startsWith("-") ? -1 : 1]
      }
      return [entry.field, entry.direction === "asc" ? 1 : -1]
    }),
  )
}

function buildProjection(collection, fields) {
  const requested = Array.isArray(fields) && fields.length > 0 ? new Set(fields) : null
  const projection = {}
  for (const field of collection.fields ?? []) {
    if (field.hidden) continue
    if (requested && !requested.has(field.name)) continue
    projection[field.name] = 1
  }
  const idField = getCollectionIdField(collection)
  projection[idField] = 1
  projection._id = 1
  return projection
}

function coerceMongoValue(field, value, options = {}) {
  const storageKind = getFieldStorageKind(field)

  if (storageKind === "objectIdArray") {
    return coerceArrayValue(value).map((item) => coerceObjectIdValue(item, options))
  }
  if (storageKind === "objectId") return coerceObjectIdValue(value, options)
  if (storageKind === "date") return coerceDateValue(value)
  if (storageKind === "dateString") return coerceDateStringValue(value)
  if (storageKind === "stringArray") {
    return coerceArrayValue(value).map((item) => String(item))
  }

  if (Array.isArray(value)) {
    return value.map((item) => coerceMongoValue(field, item, options))
  }
  if (storageKind === "number" || field.type === "number") {
    const numberValue = Number(value)
    return Number.isFinite(numberValue) ? numberValue : value
  }
  if (storageKind === "boolean" || field.type === "boolean") {
    if (typeof value === "boolean") return value
    if (value === "true" || value === "1" || value === 1) return true
    if (value === "false" || value === "0" || value === 0) return false
    return value
  }
  if (field.type === "date") return coerceDateValue(value)
  return value
}

function coerceMongoEqualityValue(field, value, options = {}) {
  if (isObjectIdField(field) && options.ObjectId && isObjectIdString(value)) {
    return { $in: [new options.ObjectId(value), value] }
  }
  return coerceMongoValue(field, value, options)
}

function coerceMongoInValues(field, value, options = {}) {
  const values = Array.isArray(value) ? value : [value]
  return values.flatMap((item) => {
    if (isObjectIdField(field) && options.ObjectId && isObjectIdString(item)) {
      return [new options.ObjectId(item), item]
    }
    return [coerceMongoValue(field, item, options)]
  })
}

function isObjectIdField(field) {
  const storageKind = getFieldStorageKind(field)
  return (
    storageKind === "objectId" ||
    storageKind === "objectIdArray" ||
    field.type === "id" ||
    field.type === "relation" ||
    field.type === "relationMany"
  )
}

function getFieldStorageKind(field) {
  if (field.storage?.kind) return field.storage.kind
  if (field.type === "id" || field.type === "relation") return "objectId"
  if (field.type === "relationMany") return "objectIdArray"
  if (field.type === "date") return "date"
  if (field.type === "multiSelect") return "stringArray"
  if (field.type === "number") return "number"
  if (field.type === "boolean") return "boolean"
  if (field.type === "json") return "json"
  if (field.type === "object") return "object"
  if (field.type === "array") return "array"
  return "string"
}

function getFieldValidationIssue(field, value) {
  const label = field.label ?? field.name
  if (isBlankValue(value)) return field.required ? `${label} is required.` : null

  if (field.type === "number") {
    const number = Number(value)
    if (!Number.isFinite(number)) return `${label} must be a number.`
    if (field.validation?.min !== undefined && number < field.validation.min) {
      return `${label} must be at least ${field.validation.min}.`
    }
    if (field.validation?.max !== undefined && number > field.validation.max) {
      return `${label} must be at most ${field.validation.max}.`
    }
    return null
  }

  if (field.type === "date") {
    const date = value instanceof Date ? value : new Date(String(value))
    return Number.isNaN(date.getTime()) ? `${label} must be a date.` : null
  }

  if (field.type === "select") return validateOptions(field, [String(value)])
  if (field.type === "multiSelect") return validateOptions(field, toStringArray(value))

  if (isTextField(field)) {
    const text = String(value)
    if (field.validation?.minLength !== undefined && text.length < field.validation.minLength) {
      return `${label} must be at least ${field.validation.minLength} characters.`
    }
    if (field.validation?.maxLength !== undefined && text.length > field.validation.maxLength) {
      return `${label} must be at most ${field.validation.maxLength} characters.`
    }
    if (field.validation?.pattern && !new RegExp(field.validation.pattern).test(text)) {
      return `${label} is invalid.`
    }
  }

  return null
}

function validateOptions(field, values) {
  const options = (field.options ?? []).map(optionValue).filter(Boolean)
  if (options.length === 0) return null
  const invalid = values.find((value) => !options.includes(value))
  if (!invalid) return null
  const label = field.label ?? field.name
  return `${label} must be one of: ${options.join(", ")}.`
}

function optionValue(option) {
  return typeof option === "string" ? option : option.value
}

function isTextField(field) {
  return ["id", "text", "textarea", "relation"].includes(field.type)
}

function toStringArray(value) {
  if (Array.isArray(value)) return value.map((item) => String(item))
  if (typeof value === "string") {
    return value
      .split(",")
      .map((item) => item.trim())
      .filter(Boolean)
  }
  return value == null ? [] : [String(value)]
}

function coerceArrayValue(value) {
  if (Array.isArray(value)) return value
  if (typeof value === "string") {
    return value
      .split(",")
      .map((item) => item.trim())
      .filter(Boolean)
  }
  return value == null ? [] : [value]
}

function coerceObjectIdValue(value, options = {}) {
  if (options.ObjectId && isObjectIdString(value)) return new options.ObjectId(value)
  return value
}

function coerceDateValue(value) {
  if (value instanceof Date) return value
  if (typeof value !== "string") return value
  const date = new Date(value)
  return Number.isNaN(date.getTime()) ? value : date
}

function coerceDateStringValue(value) {
  const date = coerceDateValue(value)
  return date instanceof Date ? date.toISOString() : value
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

function isBlankValue(value) {
  if (value === undefined || value === null) return true
  if (typeof value === "string") return value.trim().length === 0
  if (Array.isArray(value)) return value.length === 0
  return false
}

function isObjectIdString(value) {
  return typeof value === "string" && /^[a-f0-9]{24}$/i.test(value)
}

function isObjectIdLike(value) {
  return (
    typeof value === "object" &&
    value !== null &&
    "toHexString" in value &&
    typeof value.toHexString === "function"
  )
}

function stringValue(value) {
  return typeof value === "string" && value.trim() ? value.trim() : undefined
}
