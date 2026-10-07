// Model.js is a QML JavaScript library, loaded into a sandbox with its
// `.pragma library` line stripped. Run with: node --test tests/*.test.mjs
import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import vm from "node:vm"

const source = readFileSync(new URL("../Model.js", import.meta.url), "utf8").replace(/^\.pragma library\s*$/m, "")
const M = vm.createContext({})
vm.runInContext(source, M)

test("formatBytes", () => {
  assert.equal(M.formatBytes(0), "0 B")
  assert.equal(M.formatBytes(1536), "1.5 KB")
  assert.equal(M.formatBytes(150 * 1024 ** 3), "150 GB")
  assert.equal(M.formatBytes(-1), "?")
})

test("parseDf", () => {
  const df = M.parseDf("    1B-blocks         Avail\n1998232485888 199823248588\n")
  assert.equal(df.size, 1998232485888)
  assert.ok(Math.abs(df.percent - 10) < 0.01)
  assert.equal(M.parseDf(""), null)
  assert.equal(M.parseDf("header\nfoo bar"), null)
})

test("parseScan sorts by reclaim and sinks count-only rows", () => {
  const list = M.parseScan(JSON.stringify([
    { id: "snapper", reclaim: -1 }, { id: "trash", reclaim: 10 }, { id: "pacman", reclaim: 500 }, { id: "journal", reclaim: 0 },
  ]))
  assert.deepEqual(Array.from(list, (c) => c.id), ["pacman", "trash", "journal", "snapper"])
  assert.equal(M.totalReclaim(list), 510)
  assert.equal(M.parseScan("not json").length, 0)
})
