#!/usr/bin/env node
import { loadCmsConfigFromDir } from "../contract/files.mjs"
import { listGeneratedOperations, validateCmsConfig } from "../contract/index.mjs"

const [command, rootDir = process.cwd()] = process.argv.slice(2)

if (!command || !["validate", "tools"].includes(command)) {
  console.error("Usage: node cms/bin/cms.mjs <validate|tools> <cms-config-dir>")
  process.exit(2)
}

try {
  const config = await loadCmsConfigFromDir(rootDir)
  if (command === "validate") {
    const result = validateCmsConfig(config)
    if (!result.ok) {
      console.error(JSON.stringify(result, null, 2))
      process.exit(1)
    }
    console.log(JSON.stringify({ ok: true, collections: Object.keys(config.collections) }, null, 2))
  }

  if (command === "tools") {
    console.log(JSON.stringify(listGeneratedOperations(config), null, 2))
  }
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error))
  process.exit(1)
}

