import {
  CmsConfigError,
  applyInMemoryFilters,
  applyInMemorySort,
  assertOperationAllowed,
  getCollection,
  getCollectionIdField,
  validateDocument,
} from "../../contract/index.mjs"

export function createGithubCmsAdapter(options) {
  const { config, transport, approved = false } = options
  if (!transport) throw new CmsConfigError(["GitHub adapter requires a transport"])

  return {
    async list(collectionName, query = {}) {
      assertOperationAllowed(config, collectionName, "list")
      const collection = getCollection(config, collectionName)
      const docs = await readCollectionDocs(transport, collection)
      const filtered = applyInMemoryFilters(docs, collection, query.filters ?? {})
      const sorted = applyInMemorySort(filtered, query.sort ?? collection.defaultSort)
      const offset = Math.max(0, Number(query.offset ?? 0))
      const limit = Math.max(1, Math.min(100, Number(query.limit ?? 50)))
      return {
        docs: sorted.slice(offset, offset + limit),
        total: sorted.length,
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
      const collection = getCollection(config, collectionName)
      return readDoc(transport, collection, id).catch((error) => {
        if (error?.status === 404 || error?.code === "ENOENT") return null
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
      const id = validation.value[getCollectionIdField(collection)] ?? validation.value.id
      if (!id) throw new CmsConfigError([`${collectionName} create requires an id`])
      await transport.writeFile(docPath(collection, id), JSON.stringify(validation.value, null, 2) + "\n", {
        message: `cms: create ${collectionName}/${id}`,
      })
      return this.get(collectionName, id)
    },

    async update(collectionName, id, data, operationOptions = {}) {
      assertOperationAllowed(config, collectionName, "update", {
        approved: operationOptions.approved ?? approved,
      })
      const collection = getCollection(config, collectionName)
      const current = await readDoc(transport, collection, id)
      const next = { ...current, ...data }
      const validation = validateDocument(collection, next)
      if (!validation.ok) throw new CmsConfigError(validation.errors)
      await transport.writeFile(docPath(collection, id), JSON.stringify(validation.value, null, 2) + "\n", {
        message: `cms: update ${collectionName}/${id}`,
      })
      return this.get(collectionName, id)
    },

    async delete(collectionName, id, operationOptions = {}) {
      assertOperationAllowed(config, collectionName, "delete", {
        approved: operationOptions.approved ?? approved,
      })
      const collection = getCollection(config, collectionName)
      await transport.deleteFile(docPath(collection, id), {
        message: `cms: delete ${collectionName}/${id}`,
      })
      return { deleted: true }
    },
  }
}

export function createGitHubContentsTransport({ octokit, owner, repo, branch }) {
  return {
    async listFiles(rootPath) {
      const { data } = await octokit.repos.getContent({ owner, repo, path: rootPath, ref: branch })
      return Array.isArray(data)
        ? data.filter((item) => item.type === "file").map((item) => item.path)
        : []
    },

    async readFile(filePath) {
      const { data } = await octokit.repos.getContent({ owner, repo, path: filePath, ref: branch })
      if (Array.isArray(data) || !data.content) throw Object.assign(new Error("not a file"), { status: 404 })
      return Buffer.from(data.content, "base64").toString("utf8")
    },

    async writeFile(filePath, content, { message }) {
      let sha
      try {
        const { data } = await octokit.repos.getContent({ owner, repo, path: filePath, ref: branch })
        if (!Array.isArray(data)) sha = data.sha
      } catch (error) {
        if (error?.status !== 404) throw error
      }
      await octokit.repos.createOrUpdateFileContents({
        owner,
        repo,
        path: filePath,
        branch,
        message,
        sha,
        content: Buffer.from(content).toString("base64"),
      })
    },

    async deleteFile(filePath, { message }) {
      const { data } = await octokit.repos.getContent({ owner, repo, path: filePath, ref: branch })
      if (Array.isArray(data)) throw Object.assign(new Error("not a file"), { status: 400 })
      await octokit.repos.deleteFile({ owner, repo, path: filePath, branch, message, sha: data.sha })
    },
  }
}

async function readCollectionDocs(transport, collection) {
  const rootPath = collection.source.path ?? collection.name
  const files = await transport.listFiles(rootPath)
  const extension = collection.source.extension ?? "json"
  const docs = []
  for (const filePath of files.filter((file) => file.endsWith(`.${extension}`))) {
    docs.push(JSON.parse(await transport.readFile(filePath)))
  }
  return docs
}

async function readDoc(transport, collection, id) {
  return JSON.parse(await transport.readFile(docPath(collection, id)))
}

function docPath(collection, id) {
  const rootPath = collection.source.path ?? collection.name
  const extension = collection.source.extension ?? "json"
  return `${rootPath}/${id}.${extension}`
}
