.pragma library

// Pure helpers for the bar label and the panel, tested with plain Node.

// 1536 -> "1.5 KB". Binary steps with the short units people read on a bar.
function formatBytes(bytes) {
  var n = Number(bytes)
  if (!isFinite(n) || n < 0) return "?"
  var units = ["B", "KB", "MB", "GB", "TB", "PB"]
  var i = 0
  while (n >= 1024 && i < units.length - 1) { n /= 1024; i++ }
  return (i === 0 || n >= 100 ? Math.round(n) : n.toFixed(1)) + " " + units[i]
}

// `df -B1 --output=size,avail /` -> { size, avail, percent } or null.
function parseDf(text) {
  var lines = String(text || "").trim().split("\n")
  if (lines.length < 2) return null
  var f = lines[lines.length - 1].trim().split(/\s+/)
  var size = Number(f[0]), avail = Number(f[1])
  if (!(size > 0) || !(avail >= 0)) return null
  return { size: size, avail: avail, percent: avail / size * 100 }
}

// `disk-reclaim scan --json` -> categories, biggest reclaim first; count-only
// rows (reclaim -1) sink to the bottom.
function parseScan(text) {
  var list
  try { list = JSON.parse(String(text || "")) } catch (e) { return [] }
  if (!Array.isArray(list)) return []
  return list.slice().sort(function(a, b) { return Number(b.reclaim) - Number(a.reclaim) })
}

function totalReclaim(categories) {
  var t = 0
  for (var i = 0; i < categories.length; i++)
    if (categories[i].reclaim > 0) t += categories[i].reclaim
  return t
}
