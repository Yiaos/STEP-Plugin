function unique(arr) {
  return [...new Set(arr)]
}

function splitChain(command) {
  const text = String(command || "")
  const parts = []
  let cur = ""
  let quote = null

  for (let i = 0; i < text.length; i += 1) {
    const ch = text[i]
    const next = text[i + 1]

    if (quote) {
      if (ch === quote) quote = null
      cur += ch
      continue
    }

    if (ch === '"' || ch === "'") {
      quote = ch
      cur += ch
      continue
    }

    if (ch === "&" && next === "&") {
      if (cur.trim()) parts.push(cur.trim())
      cur = ""
      i += 1
      continue
    }

    if (ch === "|" && next === "|") {
      if (cur.trim()) parts.push(cur.trim())
      cur = ""
      i += 1
      continue
    }

    if (ch === ";" || ch === "|" || ch === "\n") {
      if (cur.trim()) parts.push(cur.trim())
      cur = ""
      continue
    }

    cur += ch
  }

  if (cur.trim()) parts.push(cur.trim())
  return parts
}

function tokenize(segment) {
  const text = String(segment || "")
  const tokens = []
  let cur = ""
  let quote = null

  for (let i = 0; i < text.length; i += 1) {
    const ch = text[i]
    if (quote) {
      if (ch === quote) {
        quote = null
      } else {
        cur += ch
      }
      continue
    }
    if (ch === '"' || ch === "'") {
      quote = ch
      continue
    }
    if (/\s/.test(ch)) {
      if (cur.length > 0) {
        tokens.push(cur)
        cur = ""
      }
      continue
    }
    cur += ch
  }

  if (quote) {
    throw new Error(`命令引号不闭合: ${segment}`)
  }
  if (cur.length > 0) tokens.push(cur)
  return tokens
}

function normalizeExecutableName(raw) {
  const normalized = String(raw || "").replace(/\\+$/, "")
  const parts = normalized.split("/")
  return parts[parts.length - 1] || normalized
}

function firstExecutableFromTokens(tokens) {
  if (!Array.isArray(tokens) || tokens.length === 0) {
    return { exe: "", index: -1 }
  }

  let i = 0
  let exe = tokens[i] || ""
  if (normalizeExecutableName(exe) === "env") {
    i += 1
    while (i < tokens.length) {
      const t = tokens[i]
      if (/^[A-Za-z_][A-Za-z0-9_]*=/.test(t)) {
        i += 1
        continue
      }
      exe = t
      break
    }
  }
  if (normalizeExecutableName(exe) === "command") {
    i += 1
    exe = tokens[i] || ""
  }
  return { exe: normalizeExecutableName(exe), index: i }
}

function firstExecutableFromCommand(command) {
  const tokens = tokenize(String(command || "").trim())
  if (tokens.length === 0) return ""
  return firstExecutableFromTokens(tokens).exe
}

const SHELL_WRAPPERS = new Set(["bash", "sh", "zsh", "ksh", "dash"])

function shellInnerCommand(tokens, executableIndex) {
  if (!Array.isArray(tokens) || executableIndex < 0) return ""
  for (let i = executableIndex + 1; i < tokens.length; i += 1) {
    const token = String(tokens[i] || "")
    if (!token) continue
    if (token === "--") break
    if (token === "-c" || token === "--command") {
      return String(tokens[i + 1] || "")
    }
    if (/^-[A-Za-z]+$/.test(token) && token.includes("c")) {
      return String(tokens[i + 1] || "")
    }
  }
  return ""
}

function executablesFromCommand(command, depth = 0) {
  if (!command || !String(command).trim()) return []
  if (depth > 4) return []

  const out = []
  const segments = splitChain(String(command))
  for (const seg of segments) {
    const tokens = tokenize(seg)
    if (tokens.length === 0) continue

    const first = firstExecutableFromTokens(tokens)
    if (!first.exe) continue
    out.push(first.exe)

    if (SHELL_WRAPPERS.has(first.exe)) {
      const inner = shellInnerCommand(tokens, first.index)
      if (inner) {
        out.push(...executablesFromCommand(inner, depth + 1))
      }
    }
  }
  return unique(out)
}

module.exports = {
  splitChain,
  tokenize,
  normalizeExecutableName,
  firstExecutableFromTokens,
  firstExecutableFromCommand,
  shellInnerCommand,
  executablesFromCommand,
}
