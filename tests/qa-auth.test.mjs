import assert from "node:assert/strict"
import fs from "node:fs"
import path from "node:path"
import test from "node:test"
import { fileURLToPath } from "node:url"

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..")
const profile = JSON.parse(fs.readFileSync(path.join(root, "implementations/qa-engineer/runtime.json"), "utf-8"))

test("QA repository authentication is declarative and prepared before the browser starts", () => {
  const method = profile.auth.methods[0]
  assert.equal(method.strategy, "browser-storage-state")
  assert.equal(method.adapter, "kody-repository")
  assert.deepEqual(
    method.fields.map(({ source, key }) => ({ source, key })),
    [
      { source: "variable", key: "KODY_LOGIN_REPO" },
      { source: "secret", key: "KODY_LOGIN_PASS" },
    ],
  )

  const preflight = profile.scripts.preflight.map(({ script }) => script)
  assert.ok(preflight.indexOf("prepareBrowserAuth") > preflight.indexOf("loadQaContext"))
  assert.ok(preflight.indexOf("prepareBrowserAuth") < preflight.indexOf("warmupMcp"))
})

test("QA cannot use browser tools that expose session storage or execute code", () => {
  const tools = profile.claudeCode.tools
  assert.ok(!tools.includes("Read"))
  assert.ok(!tools.includes("Grep"))
  assert.ok(!tools.includes("Glob"))
  assert.ok(!tools.includes("Bash"))
  assert.ok(tools.includes("mcp__playwright__browser_navigate"))
  assert.ok(tools.includes("mcp__playwright__browser_snapshot"))
  assert.ok(!tools.includes("mcp__playwright"))
  assert.ok(!tools.some((tool) => tool.includes("evaluate")))
  assert.ok(!tools.some((tool) => tool.includes("run_code")))
  assert.ok(!tools.some((tool) => tool.includes("storage")))
  assert.ok(!tools.some((tool) => tool.includes("network_request")))
})
