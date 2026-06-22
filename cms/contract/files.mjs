import { readFile } from "node:fs/promises"
import path from "node:path"
import { normalizeCmsConfig } from "./index.mjs"

export async function loadCmsConfigFromDir(rootDir) {
  const configPath = path.join(rootDir, "config.json")
  const rawConfig = await readJson(configPath)
  const collectionRefs = Array.isArray(rawConfig.collections) ? rawConfig.collections : []
  const collections = {}

  for (const ref of collectionRefs) {
    if (typeof ref !== "string") continue
    const collection = await readJson(path.join(rootDir, ref))
    collections[collection.name] = collection
  }

  let environment = {}
  if (typeof rawConfig.environmentFile === "string") {
    environment = await readJson(path.join(rootDir, rawConfig.environmentFile))
  }

  return normalizeCmsConfig({
    ...rawConfig,
    environment: environment.name ?? rawConfig.environment,
    defaultAdapter: environment.adapter ?? rawConfig.defaultAdapter,
    writePolicy: environment.writePolicy ?? rawConfig.writePolicy,
    adapters: {
      ...(rawConfig.adapters ?? {}),
      ...(environment.adapter
        ? {
            [environment.adapter]: {
              databaseUriSecret: environment.databaseUriSecret,
              databaseName: environment.databaseName,
            },
          }
        : {}),
    },
    collections,
  })
}

async function readJson(filePath) {
  return JSON.parse(await readFile(filePath, "utf8"))
}

