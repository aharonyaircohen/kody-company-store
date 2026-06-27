import { access, mkdir, readFile, readdir, unlink, writeFile } from "node:fs/promises"
import path from "node:path"

import {
  CmsConfigError,
  applyInMemoryFilters,
  applyInMemorySort,
  assertOperationAllowed,
  getCollection,
  getCollectionIdField,
  validateDocument,
} from "../../contract/index.mjs"

export const adapterName = "file"
export const createCmsAdapter = createFileCmsAdapter

export function createFileCmsAdapter(options) {
  const { config, approved = false } = options

  return {
    async list(collectionName, query = {}) {
      assertOperationAllowed(config, collectionName, "list")
      const collection = getCollection(config, collectionName)
      return listFileDocuments(options, collection, query)
    },

    async listByIds(collectionName, ids = []) {
      assertOperationAllowed(config, collectionName, "list")
      const collection = getCollection(config, collectionName)
      const docs = []
      for (const id of ids) {
        const doc = await readDoc(options, collection, id).catch((error) => {
          if (error?.code === "ENOENT") return null
          throw error
        })
        if (doc) docs.push(doc)
      }
      return docs
    },

    async search(collectionName, query = {}) {
      assertOperationAllowed(config, collectionName, "search")
      const collection = getCollection(config, collectionName)
      return listFileDocuments(options, collection, query)
    },

    async get(collectionName, id) {
      assertOperationAllowed(config, collectionName, "get")
      const collection = getCollection(config, collectionName)
      return readDoc(options, collection, id).catch((error) => {
        if (error?.code === "ENOENT") return null
        throw error
      })
    },

    async create(collectionName, data, operationOptions = {}) {
      assertOperationAllowed(config, collectionName, "create", {
        approved: operationOptions.approved ?? approved,
      })
      const collection = getCollection(config, collectionName)
      const validation = validateDocument(collection, data)
      if (!validation.ok) throw new CmsConfigError(validation.errors)

      const id = getDocumentId(collection, validation.value, collectionName)
      const filePath = resolveDocPath(options, collection, id)
      if (await fileExists(filePath)) {
        throw new CmsConfigError([`${collectionName}/${id} already exists`])
      }

      await writeDoc(filePath, validation.value)
      return readDoc(options, collection, id)
    },

    async update(collectionName, id, data, operationOptions = {}) {
      assertOperationAllowed(config, collectionName, "update", {
        approved: operationOptions.approved ?? approved,
      })
      const collection = getCollection(config, collectionName)
      const current = await readDoc(options, collection, id).catch((error) => {
        if (error?.code === "ENOENT") return null
        throw error
      })
      if (!current) return null

      const idField = getCollectionIdField(collection)
      if (data?.[idField] !== undefined && String(data[idField]) !== String(id)) {
        throw new CmsConfigError([`${collectionName} update cannot change ${idField}`])
      }

      const next = { ...current, ...data }
      const validation = validateDocument(collection, next)
      if (!validation.ok) throw new CmsConfigError(validation.errors)

      await writeDoc(resolveDocPath(options, collection, id), validation.value)
      return readDoc(options, collection, id)
    },

    async delete(collectionName, id, operationOptions = {}) {
      assertOperationAllowed(config, collectionName, "delete", {
        approved: operationOptions.approved ?? approved,
      })
      const collection = getCollection(config, collectionName)
      return unlink(resolveDocPath(options, collection, id))
        .then(() => ({ deleted: true }))
        .catch((error) => {
          if (error?.code === "ENOENT") return { deleted: false }
          throw error
        })
    },
  }
}

async function listFileDocuments(options, collection, query = {}) {
  const docs = await readCollectionDocs(options, collection)
  const filtered = applyInMemoryFilters(docs, collection, query.filters ?? {})
  const searched = applySearch(filtered, collection, query.search)
  const sorted = applyInMemorySort(searched, query.sort ?? collection.defaultSort)
  const offset = Math.max(0, Number(query.offset ?? 0))
  const limit = clampLimit(query.limit)

  return {
    docs: sorted.slice(offset, offset + limit),
    total: sorted.length,
    limit,
    offset,
  }
}

async function readCollectionDocs(options, collection) {
  const collectionDir = resolveCollectionDir(options, collection)
  const extension = getExtension(collection)
  let entries
  try {
    entries = await readdir(collectionDir, { withFileTypes: true })
  } catch (error) {
    if (error?.code === "ENOENT") return []
    throw error
  }

  const docs = []
  for (const entry of entries) {
    if (!entry.isFile() || !entry.name.endsWith(`.${extension}`)) continue
    docs.push(await readDocFile(path.join(collectionDir, entry.name)))
  }
  return docs
}

async function readDoc(options, collection, id) {
  return readDocFile(resolveDocPath(options, collection, id))
}

async function readDocFile(filePath) {
  const content = await readFile(filePath, "utf8")
  try {
    return JSON.parse(content)
  } catch {
    throw new CmsConfigError([`invalid JSON document: ${filePath}`])
  }
}

async function writeDoc(filePath, doc) {
  await mkdir(path.dirname(filePath), { recursive: true })
  await writeFile(filePath, `${JSON.stringify(doc, null, 2)}\n`, "utf8")
}

function applySearch(docs, collection, search) {
  const query = search?.query?.trim()
  if (!query) return docs
  const fields = search?.fields?.length
    ? search.fields
    : collection.searchFields?.length
      ? collection.searchFields
      : [collection.titleField].filter(Boolean)
  if (fields.length === 0) return docs
  const needle = query.toLowerCase()
  return docs.filter((doc) =>
    fields.some((field) => String(doc[field] ?? "").toLowerCase().includes(needle)),
  )
}

function getDocumentId(collection, data, collectionName) {
  const idField = getCollectionIdField(collection)
  const id = data?.[idField] ?? data?.id
  if (id === undefined || id === null || String(id).trim() === "") {
    throw new CmsConfigError([`${collectionName} create requires an id`])
  }
  return String(id)
}

function resolveDocPath(options, collection, id) {
  const safeId = safeDocumentId(id)
  return resolveInsideRoot(
    resolveRootDir(options),
    collectionPath(collection),
    `${safeId}.${getExtension(collection)}`,
  )
}

function resolveCollectionDir(options, collection) {
  return resolveInsideRoot(resolveRootDir(options), collectionPath(collection))
}

function collectionPath(collection) {
  return stringValue(collection.source?.path) ?? stringValue(collection.source?.collection) ?? collection.name
}

function getExtension(collection) {
  const extension = stringValue(collection.source?.extension) ?? "json"
  if (!/^[A-Za-z0-9]+$/.test(extension)) {
    throw new CmsConfigError([`unsafe file extension: ${extension}`])
  }
  if (extension !== "json") {
    throw new CmsConfigError([`file adapter only supports json documents`])
  }
  return extension
}

function resolveRootDir(options) {
  const rootDir =
    stringValue(options.rootDir) ??
    stringValue(options.settings?.rootDir) ??
    stringValue(options.config?.adapters?.file?.rootDir) ??
    stringValue(options.config?.adapters?.["store:cms-file"]?.rootDir)
  if (!rootDir) throw new CmsConfigError(["File adapter requires rootDir"])
  return path.resolve(rootDir)
}

function resolveInsideRoot(rootDir, ...segments) {
  const resolved = path.resolve(rootDir, ...segments)
  if (resolved !== rootDir && !resolved.startsWith(`${rootDir}${path.sep}`)) {
    throw new CmsConfigError(["resolved file path escapes rootDir"])
  }
  return resolved
}

function safeDocumentId(id) {
  const value = String(id)
  if (
    value.trim() === "" ||
    value.includes("\0") ||
    value.includes("/") ||
    value.includes("\\") ||
    value === "." ||
    value === ".."
  ) {
    throw new CmsConfigError([`unsafe document id: ${value}`])
  }
  return value
}

function clampLimit(limit) {
  const numeric = Number(limit ?? 50)
  if (!Number.isFinite(numeric)) return 50
  return Math.max(1, Math.min(100, numeric))
}

async function fileExists(filePath) {
  return access(filePath)
    .then(() => true)
    .catch(() => false)
}

function stringValue(value) {
  return typeof value === "string" && value.trim() ? value.trim() : undefined
}
