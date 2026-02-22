#!/usr/bin/env node

const fs = require("fs")
const path = require("path")
const { spawnSync } = require("child_process")

function fail(message, code = 1) {
  console.error(`❌ ${message}`)
  process.exit(code)
}

function info(message) {
  console.log(message)
}

function ensureFile(filePath) {
  if (!fs.existsSync(filePath)) {
    fail(`文件不存在: ${filePath}`)
  }
}

function normalizeNewlines(raw) {
  return raw.replace(/\r\n/g, "\n")
}

function readJson(filePath) {
  ensureFile(filePath)
  const raw = fs.readFileSync(filePath, "utf-8")
  try {
    return JSON.parse(raw)
  } catch (err) {
    fail(`JSON 解析失败: ${filePath} (${String(err)})`)
  }
}

function writeJsonAtomic(filePath, data) {
  const tmpPath = `${filePath}.tmp-${process.pid}`
  const content = `${JSON.stringify(data, null, 2)}\n`
  fs.writeFileSync(tmpPath, content, "utf-8")
  fs.renameSync(tmpPath, filePath)
}

function extractTaskJsonFromMarkdown(raw, filePath) {
  const text = normalizeNewlines(raw)
  const match = text.match(/```json(?:\s+task)?\n([\s\S]*?)\n```/)
  if (!match) {
    fail(`任务 Markdown 缺少 JSON 代码块: ${filePath}`)
  }
  try {
    return JSON.parse(match[1])
  } catch (err) {
    fail(`任务 JSON 解析失败: ${filePath} (${String(err)})`)
  }
}

function readTask(filePath) {
  ensureFile(filePath)
  const raw = fs.readFileSync(filePath, "utf-8")
  if (filePath.endsWith(".md")) {
    return extractTaskJsonFromMarkdown(raw, filePath)
  }
  return readJson(filePath)
}

function renderTaskMarkdown(task) {
  const title = typeof task.title === "string" && task.title.trim() ? task.title.trim() : task.id || "Task"
  return [
    `# ${title}`,
    "",
    "```json task",
    JSON.stringify(task, null, 2),
    "```",
    "",
  ].join("\n")
}

function writeTaskAtomic(filePath, task) {
  const tmpPath = `${filePath}.tmp-${process.pid}`
  const content = filePath.endsWith(".md") ? renderTaskMarkdown(task) : `${JSON.stringify(task, null, 2)}\n`
  fs.writeFileSync(tmpPath, content, "utf-8")
  fs.renameSync(tmpPath, filePath)
}

function readStdinText() {
  try {
    if (process.stdin.isTTY) return ""
    return fs.readFileSync(0, "utf-8")
  } catch {
    return ""
  }
}

function ensureAgentsBlock(filePath, begin, end, blockContent) {
  const section = `${begin}\n${blockContent}\n${end}`
  let current = ""
  if (fs.existsSync(filePath)) {
    current = fs.readFileSync(filePath, "utf-8")
  }

  if (!current) {
    fs.writeFileSync(filePath, `# AGENTS\n\n${section}\n`, "utf-8")
    return
  }

  const beginIdx = current.indexOf(begin)
  const endIdx = current.indexOf(end)
  let next
  if (beginIdx >= 0 && endIdx > beginIdx) {
    const head = current.slice(0, beginIdx)
    const tail = current.slice(endIdx + end.length)
    next = `${head}${section}${tail}`
  } else {
    const normalized = current.endsWith("\n") ? current : `${current}\n`
    next = `${normalized}\n${section}\n`
  }
  fs.writeFileSync(filePath, next, "utf-8")
}

function isObject(v) {
  return typeof v === "object" && v !== null && !Array.isArray(v)
}

function validateState(state) {
  const errors = []
  if (!isObject(state)) {
    errors.push("state 需为对象")
    return errors
  }
  const required = [
    "project",
    "current_phase",
    "current_change",
    "last_updated",
    "last_agent",
    "last_session_summary",
    "session",
    "established_patterns",
    "tasks",
    "key_decisions",
    "known_issues",
    "constraints_quick_ref",
    "progress_log",
  ]
  for (const k of required) {
    if (!(k in state)) {
      errors.push(`缺少字段: ${k}`)
    }
  }
  if ("tasks" in state) {
    if (!isObject(state.tasks)) {
      errors.push("tasks 必须是对象")
    } else {
      if (!("current" in state.tasks)) {
        errors.push("tasks.current 缺失")
      } else {
        const t = state.tasks.current
        if (!(t === null || typeof t === "string")) {
          errors.push("tasks.current 必须是 string 或 null")
        }
      }
      if (!("upcoming" in state.tasks) || !Array.isArray(state.tasks.upcoming)) {
        errors.push("tasks.upcoming 必须是数组")
      }
    }
  }
  if (!("session" in state) || !isObject(state.session)) {
    errors.push("session 必须是对象")
  } else {
    if (!("mode" in state.session) || typeof state.session.mode !== "string") {
      errors.push("session.mode 必须是字符串")
    } else if (!["full", "lite", "quick"].includes(state.session.mode)) {
      errors.push("session.mode 必须是 full/lite/quick")
    }
  }
  return errors
}

function validateTask(task) {
  const errors = []
  if (!isObject(task)) {
    errors.push("task 需为对象")
    return errors
  }
  const required = ["id", "title", "mode", "status", "scenarios", "done_when"]
  for (const k of required) {
    if (!(k in task)) {
      errors.push(`缺少字段: ${k}`)
    }
  }
  if ("mode" in task && !(task.mode === "full" || task.mode === "lite")) {
    errors.push("mode 必须是 full 或 lite")
  }
  if ("done_when" in task && !Array.isArray(task.done_when)) {
    errors.push("done_when 必须是数组")
  }
  if ("scenarios" in task) {
    const s = task.scenarios
    if (!(Array.isArray(s) || isObject(s))) {
      errors.push("scenarios 必须是数组或对象")
    }
    const entries = collectScenarioEntries(task)
    for (const entry of entries) {
      if ("status" in entry) {
        const st = entry.status
        if (typeof st !== "string" || !["not_run", "pass", "fail"].includes(st)) {
          errors.push("scenario.status 必须是 not_run/pass/fail")
          break
        }
      }
    }
    if (task.status === "done") {
      const summary = scenarioStatusSummary(task)
      if (summary.notRun > 0) {
        errors.push("task.status=done 时不允许存在 scenario.status=not_run")
      }
      if (summary.fail > 0) {
        errors.push("task.status=done 时不允许存在 scenario.status=fail")
      }
    }
  }
  return errors
}

function validateConfig(config) {
  const errors = []
  if (!isObject(config)) {
    errors.push("config 需为对象")
    return errors
  }
  if (!isObject(config.routing)) {
    errors.push("routing 必须是对象")
  }
  if (!isObject(config.file_routing)) {
    errors.push("file_routing 必须是对象")
  }
  if (!isObject(config.gate)) {
    errors.push("gate 必须是对象")
  } else {
    for (const k of ["lint", "typecheck", "test", "build"]) {
      if (!(k in config.gate) || typeof config.gate[k] !== "string") {
        errors.push(`gate.${k} 必须是字符串`) 
      }
    }
    if ("dangerous_executables" in config.gate && !Array.isArray(config.gate.dangerous_executables)) {
      errors.push("gate.dangerous_executables 必须是数组")
    }
  }

  if ("worktree" in config) {
    if (!isObject(config.worktree)) {
      errors.push("worktree 必须是对象")
    } else {
      if ("enabled" in config.worktree && typeof config.worktree.enabled !== "boolean") {
        errors.push("worktree.enabled 必须是布尔值")
      }
      if ("branch_prefix" in config.worktree && typeof config.worktree.branch_prefix !== "string") {
        errors.push("worktree.branch_prefix 必须是字符串")
      }
    }
  }

  if ("enforcement" in config) {
    if (!isObject(config.enforcement)) {
      errors.push("enforcement 必须是对象")
    } else {
      const pairs = [
        ["require_dispatch", "enforcement.require_dispatch"],
        ["planning_phase_write_lock", "enforcement.planning_phase_write_lock"],
      ]
      for (const [key, label] of pairs) {
        if (key in config.enforcement) {
          const obj = config.enforcement[key]
          if (typeof obj === "boolean") {
            continue
          }
          if (!isObject(obj)) {
            errors.push(`${label} 必须是对象或布尔值`)
            continue
          }
          for (const mode of ["full", "lite"]) {
            if (mode in obj && typeof obj[mode] !== "boolean") {
              errors.push(`${label}.${mode} 必须是布尔值`)
            }
          }
        }
      }
      if ("bypass_tools" in config.enforcement) {
        if (!Array.isArray(config.enforcement.bypass_tools)) {
          errors.push("enforcement.bypass_tools 必须是数组")
        } else if (config.enforcement.bypass_tools.some((v) => typeof v !== "string")) {
          errors.push("enforcement.bypass_tools 必须是字符串数组")
        }
      }
    }
  }
  return errors
}

function parseArgs(argv) {
  const args = {}
  for (let i = 0; i < argv.length; i += 1) {
    const cur = argv[i]
    if (cur.startsWith("--")) {
      const key = cur.slice(2)
      const val = argv[i + 1]
      if (!val || val.startsWith("--")) {
        args[key] = true
      } else {
        args[key] = val
        i += 1
      }
    }
  }
  return args
}

function getPathValue(obj, dotPath) {
  const parts = String(dotPath).split(".")
  let cur = obj
  for (const p of parts) {
    if (!isObject(cur) && !Array.isArray(cur)) {
      return undefined
    }
    cur = cur[p]
    if (cur === undefined) return undefined
  }
  return cur
}

function resolveTaskFile(taskSlug, changeName) {
  const byChange = (change) => path.join(".step", "changes", change, "tasks", `${taskSlug}.md`)

  if (changeName) {
    const p = byChange(changeName)
    if (!fs.existsSync(p)) {
      fail(`未找到任务文件: ${p}`)
    }
    return { taskFile: p, change: changeName }
  }

  if (fs.existsSync(".step/state.json")) {
    const state = readJson(".step/state.json")
    const cur = state && typeof state.current_change === "string" ? state.current_change.trim() : ""
    if (cur) {
      const p = byChange(cur)
      if (fs.existsSync(p)) {
        return { taskFile: p, change: cur }
      }
    }
  }

  const base = path.join(".step", "changes")
  if (!fs.existsSync(base)) {
    fail("未找到 .step/changes 目录")
  }
  const matches = []
  for (const change of fs.readdirSync(base)) {
    const p = byChange(change)
    if (fs.existsSync(p)) {
      matches.push({ taskFile: p, change })
    }
  }
  if (matches.length === 1) {
    return matches[0]
  }
  if (matches.length > 1) {
    fail(`任务 slug 存在多处: ${taskSlug}，请传 --change`) 
  }
  fail(`未找到任务: ${taskSlug}`)
}

function collectScenarioEntries(task) {
  const out = []
  if (Array.isArray(task.scenarios)) {
    for (const s of task.scenarios) {
      if (isObject(s)) out.push(s)
    }
    return out
  }
  if (isObject(task.scenarios)) {
    for (const key of Object.keys(task.scenarios)) {
      const arr = task.scenarios[key]
      if (!Array.isArray(arr)) continue
      for (const s of arr) {
        if (isObject(s)) out.push(s)
      }
    }
  }
  return out
}

function isCommentLineForFile(line, filePath) {
  const trimmed = String(line || "").trim()
  if (!trimmed) return false
  const lower = String(filePath || "").toLowerCase()
  if (lower.endsWith(".sh") || lower.endsWith(".bash") || lower.endsWith(".zsh")) {
    return trimmed.startsWith("#")
  }
  if (lower.endsWith(".js") || lower.endsWith(".ts") || lower.endsWith(".tsx") || lower.endsWith(".jsx")) {
    return trimmed.startsWith("//") || trimmed.startsWith("/*") || trimmed.startsWith("*")
  }
  return false
}

function containsTokenInExecutableLine(content, token, filePath) {
  if (!token) return false
  const lines = String(content || "").split(/\r?\n/)
  const lower = String(filePath || "").toLowerCase()
  const isShell = lower.endsWith(".sh") || lower.endsWith(".bash") || lower.endsWith(".zsh")
  for (const line of lines) {
    if (!line.includes(token)) continue
    if (isCommentLineForFile(line, filePath)) continue
    if (isShell) {
      const trimmed = line.trim()
      const m = trimmed.match(/(^|\s)(assert)\b/)
      if (!m) {
        continue
      }
      if (m[2] === "assert") {
        const cmdMatch = trimmed.match(/^assert\s+["'][^"']*\[[^\]]+\][^"']*["']\s*(.*)$/)
        const cmdPart = cmdMatch ? String(cmdMatch[1] || "").trim() : ""
        const trivial =
          !cmdPart ||
          /^(true|:|echo\b|\/bin\/true\b|\/usr\/bin\/true\b|command\s+true\b|env\s+true\b)/.test(cmdPart)
        if (trivial) {
          continue
        }
      }
    }
    return true
  }
  return false
}

function flattenScenarios(task) {
  return collectScenarioEntries(task)
    .filter((s) => s.id && s.test_file)
    .map((s) => ({ id: s.id, test_file: s.test_file, status: s.status }))
}

function scenarioStatusSummary(task) {
  const entries = collectScenarioEntries(task)
  let total = 0
  let pass = 0
  let fail = 0
  let notRun = 0
  for (const s of entries) {
    if (!s.id || !s.test_file) continue
    total += 1
    const st = typeof s.status === "string" ? s.status : "not_run"
    if (st === "pass") pass += 1
    else if (st === "fail") fail += 1
    else notRun += 1
  }
  return { total, pass, fail, notRun }
}

function unique(arr) {
  return [...new Set(arr)]
}

function ensureEvidenceDir(change) {
  fs.mkdirSync(path.join(".step", "changes", change, "evidence"), { recursive: true })
}

function resolveEvidencePath(taskSlug, changeName) {
  let change = changeName
  if (!change) {
    const resolved = resolveTaskFile(taskSlug, null)
    change = resolved.change
  }
  ensureEvidenceDir(change)
  return {
    path: path.join(".step", "changes", change, "evidence", `${taskSlug}-gate.json`),
    change,
  }
}

function readEvidenceObject(paths) {
  const candidates = Array.isArray(paths) ? paths : [paths]
  for (const evidencePath of candidates) {
    if (!fs.existsSync(evidencePath)) continue
    try {
      const obj = JSON.parse(fs.readFileSync(evidencePath, "utf-8"))
      return isObject(obj) ? obj : {}
    } catch {
      continue
    }
  }
  return {}
}

function isoNow() {
  return new Date().toISOString().replace(/\.\d{3}Z$/, "Z")
}

function writeScenarioEvidence(taskSlug, change, taskFile, total, covered) {
  const resolved = resolveEvidencePath(taskSlug, change)
  const evidencePath = resolved.path
  const cov = total > 0 ? Math.floor((covered * 100) / total) : 0
  const scenario = {
    task_id: taskSlug,
    change,
    task_file: taskFile,
    timestamp: isoNow(),
    total,
    covered,
    coverage_pct: cov,
    passed: cov === 100,
  }
  const existing = readEvidenceObject(evidencePath)
  const merged = {
    ...existing,
    task_id: taskSlug,
    scenario,
  }
  fs.writeFileSync(evidencePath, `${JSON.stringify(merged, null, 2)}\n`, "utf-8")
}

function checkScenarioCoverage(taskSlug, changeName) {
  const { taskFile, change } = resolveTaskFile(taskSlug, changeName)
  const task = readTask(taskFile)
  const scenarios = collectScenarioEntries(task)

  let total = 0
  let covered = 0
  const missing = []

  for (const s of scenarios) {
    if (!s.id || !s.test_file) {
      continue
    }
    total += 1
    if (!fs.existsSync(s.test_file)) {
      s.status = "fail"
      missing.push(`${s.id} not found in ${s.test_file}`)
      continue
    }
    const content = fs.readFileSync(s.test_file, "utf-8")
    const marker = `[${s.id}]`
    if (containsTokenInExecutableLine(content, marker, s.test_file)) {
      s.status = "pass"
      covered += 1
    } else {
      s.status = "fail"
      if (content.includes(marker)) {
        missing.push(`${s.id} found only in non-verifiable lines of ${s.test_file}`)
      } else {
        missing.push(`${s.id} not found in ${s.test_file}`)
      }
    }
  }

  writeTaskAtomic(taskFile, task)

  const cov = total > 0 ? Math.floor((covered * 100) / total) : 0
  writeScenarioEvidence(taskSlug, change, taskFile, total, covered)

  info(`🔍 Checking scenario coverage for ${taskSlug} (change: ${change})...`)
  info(`📊 Coverage: ${covered}/${total} (${cov}%)`)
  if (missing.length > 0) {
    info("\nMissing:")
    for (const m of missing) {
      info(`  ❌ ${m}`)
    }
  }

  if (cov === 100) {
    info("✅ Scenario coverage PASS")
    return 0
  }
  info("❌ Scenario coverage FAIL (need 100%)")
  return 1
}

function splitChain(command) {
  const parts = []
  let cur = ""
  let quote = null
  for (let i = 0; i < command.length; i += 1) {
    const ch = command[i]
    const next = command[i + 1]

    if (quote) {
      if (ch === quote) {
        quote = null
      }
      cur += ch
      continue
    }

    if (ch === '"' || ch === "'") {
      quote = ch
      cur += ch
      continue
    }

    if (ch === "&" && next === "&") {
      if (cur.trim()) {
        parts.push(cur.trim())
      }
      cur = ""
      i += 1
      continue
    }

    cur += ch
  }
  if (cur.trim()) {
    parts.push(cur.trim())
  }
  return parts
}

function tokenize(segment) {
  const tokens = []
  let cur = ""
  let quote = null

  for (let i = 0; i < segment.length; i += 1) {
    const ch = segment[i]
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
    fail(`命令引号不闭合: ${segment}`)
  }
  if (cur.length > 0) {
    tokens.push(cur)
  }
  return tokens
}

function sanitizeTokens(tokens, dangerousExecutables) {
  if (tokens.length === 0) {
    fail("空命令段")
  }
  const exe = tokens[0]
  if (dangerousExecutables.has(exe)) {
    fail(`命中危险命令黑名单: ${exe}`)
  }
}

function runSafeCommand(command, dangerousExecutables) {
  const segments = splitChain(command)
  for (const seg of segments) {
    const tokens = tokenize(seg)
    sanitizeTokens(tokens, dangerousExecutables)
    const exe = tokens[0]
    const args = tokens.slice(1)
    const p = spawnSync(exe, args, {
      stdio: "inherit",
      env: process.env,
      cwd: process.cwd(),
    })
    if (p.status !== 0) {
      return p.status || 1
    }
  }
  return 0
}

function getGateCommands(configPath) {
  const defaults = {
    lint: "pnpm lint --no-error-on-unmatched-pattern",
    typecheck: "pnpm tsc --noEmit",
    test: "pnpm vitest run",
    build: "pnpm build",
    dangerous_executables: [
      "rm",
      "dd",
      "mkfs",
      "shutdown",
      "reboot",
      "poweroff",
      "halt",
      "sudo",
      "chown",
      "chmod",
      "passwd",
      "useradd",
      "usermod",
      "deluser",
      "killall",
      "pkill",
      "launchctl",
    ],
  }
  if (!fs.existsSync(configPath)) {
    return defaults
  }
  const cfg = readJson(configPath)
  const errs = validateConfig(cfg)
  if (errs.length > 0) {
    fail(`config 校验失败: ${errs.join("; ")}`)
  }
  return {
    lint: cfg.gate.lint || defaults.lint,
    typecheck: cfg.gate.typecheck || defaults.typecheck,
    test: cfg.gate.test || defaults.test,
    build: cfg.gate.build || defaults.build,
    dangerous_executables: Array.isArray(cfg.gate.dangerous_executables)
      ? cfg.gate.dangerous_executables.map((v) => String(v))
      : defaults.dangerous_executables,
  }
}

function writeGateEvidence(taskSlug, level, pass, results, metadata) {
  const resolved = resolveEvidencePath(taskSlug, null)
  const evidencePath = resolved.path
  const existing = readEvidenceObject(evidencePath)
  const payload = {
    ...existing,
    task_id: taskSlug,
    level,
    timestamp: isoNow(),
    passed: pass,
    results,
    ...(metadata || {}),
  }
  fs.writeFileSync(evidencePath, `${JSON.stringify(payload, null, 2)}\n`, "utf-8")
  info(`📄 Evidence saved: ${evidencePath}`)
}

function todayUTC() {
  return new Date().toISOString().slice(0, 10)
}

function patchProgressEntry(filePath, taskSlug, fields) {
  if (!fs.existsSync(filePath)) return
  const state = readJson(filePath)
  if (!isObject(state)) return
  if (!Array.isArray(state.progress_log)) {
    state.progress_log = []
  }
  const date = todayUTC()
  let idx = state.progress_log.findIndex(
    (item) => isObject(item) && item.task === taskSlug && item.date === date,
  )
  if (idx < 0) {
    const base = { date, task: taskSlug, summary: "", next_action: "" }
    state.progress_log.unshift(base)
    idx = 0
  }
  const entry = state.progress_log[idx]
  Object.assign(entry, fields)
  writeJsonAtomic(filePath, state)
}

function trimProgressForPrint(filePath, limit) {
  const state = readJson(filePath)
  if (isObject(state) && Array.isArray(state.progress_log)) {
    state.progress_log = state.progress_log.slice(0, limit)
  }
  return `${JSON.stringify(state, null, 2)}\n`
}

function renderStatusReport(root = ".step") {
  const statePath = path.join(root, "state.json")
  if (!fs.existsSync(statePath)) {
    return "STEP 未初始化（缺少 .step/state.json）"
  }
  const state = readJson(statePath)
  const phase = state.current_phase || "unknown"
  const change = state.current_change || ""
  const currentTask = state.tasks && state.tasks.current ? state.tasks.current : "null"

  let total = 0
  let done = 0
  const changesDir = path.join(root, "changes")
  if (fs.existsSync(changesDir)) {
    for (const ch of fs.readdirSync(changesDir)) {
      const taskDir = path.join(changesDir, ch, "tasks")
      if (!fs.existsSync(taskDir)) continue
      for (const tf of fs.readdirSync(taskDir)) {
        if (!tf.endsWith(".md")) continue
        total += 1
        const t = readTask(path.join(taskDir, tf))
        if (t && t.status === "done") done += 1
      }
    }
  }

  const evidenceDirs = []
  const changesForEvidence = path.join(root, "changes")
  if (fs.existsSync(changesForEvidence)) {
    for (const ch of fs.readdirSync(changesForEvidence)) {
      evidenceDirs.push(path.join(changesForEvidence, ch, "evidence"))
    }
  }
  let gatePass = 0
  let gateFail = 0
  for (const evidenceDir of evidenceDirs) {
    if (!fs.existsSync(evidenceDir)) continue
    for (const f of fs.readdirSync(evidenceDir)) {
      if (!f.endsWith("-gate.json")) continue
      const payload = JSON.parse(fs.readFileSync(path.join(evidenceDir, f), "utf-8"))
      if (payload.passed) gatePass += 1
      else gateFail += 1
    }
  }

  const issues = Array.isArray(state.known_issues) ? state.known_issues : []
  const topIssue = issues.length > 0 ? JSON.stringify(issues[0]) : "(none)"

  return [
    "STEP Status",
    `- Phase: ${phase}`,
    `- Change: ${change || "(none)"}`,
    `- Task: ${currentTask}`,
    `- Progress: ${done}/${total}`,
    `- Gate Evidence: PASS=${gatePass}, FAIL=${gateFail}`,
    `- Top Blocking Issue: ${topIssue}`,
  ].join("\n")
}

function getTaskTestFiles(taskSlug, changeName) {
  const { taskFile } = resolveTaskFile(taskSlug, changeName || null)
  const task = readTask(taskFile)
  const scenarios = flattenScenarios(task)
  return unique(scenarios.map((s) => s.test_file)).sort()
}

function applyIncrementalTestFiles(baseCommand, testFiles) {
  if (!Array.isArray(testFiles) || testFiles.length === 0) {
    return { command: baseCommand, applied: false, reason: "no-test-files" }
  }
  if (baseCommand.includes("{{test_files}}")) {
    return {
      command: baseCommand.replace("{{test_files}}", testFiles.join(" ")),
      applied: true,
      reason: "placeholder",
    }
  }

  const normalizePathToken = (token) => String(token || "").trim().replace(/^\.\//, "")
  const isLikelyShellTestFile = (token) => /^tests\/[^\s]+\.sh$/.test(token)
  const targetSet = new Set(testFiles.map((f) => normalizePathToken(f)))

  const segments = splitChain(baseCommand)
  if (segments.length !== 1) {
    const selected = []
    for (const seg of segments) {
      const tokens = tokenize(seg).map((t) => normalizePathToken(t))
      const candidates = tokens.filter((t) => isLikelyShellTestFile(t))
      if (candidates.length === 0) {
        return { command: baseCommand, applied: false, reason: "multi-segment-non-test-segment" }
      }
      if (candidates.some((t) => targetSet.has(t))) {
        selected.push(seg)
      }
    }
    if (selected.length === 0) {
      return { command: baseCommand, applied: false, reason: "multi-segment-no-match" }
    }
    return {
      command: selected.join(" && "),
      applied: true,
      reason: "segment-filter",
    }
  }
  return {
    command: `${baseCommand} ${testFiles.join(" ")}`,
    applied: true,
    reason: "append-args",
  }
}

function runGate(level, taskSlug, configPath, mode, metadata) {
  if (!(level === "quick" || level === "lite" || level === "full")) {
    fail(`不支持的 gate 级别: ${level}`)
  }
  if (!taskSlug) {
    fail("gate 需要 task slug，例如: gate run --level lite --task user-register-api", 2)
  }
  if (!(mode === "incremental" || mode === "all")) {
    fail(`不支持的 gate mode: ${mode}`)
  }

  const commands = getGateCommands(configPath)
  const dangerousExecutables = new Set(commands.dangerous_executables)
  const testFiles = level === "quick" ? [] : getTaskTestFiles(taskSlug, null)
  let testCommand = commands.test
  let testScope = "all"
  if (mode === "incremental") {
    const applied = applyIncrementalTestFiles(commands.test, testFiles)
    if (applied.applied) {
      testCommand = applied.command
      testScope = "incremental"
    } else {
      info(`⚠️ 增量测试未生效（${applied.reason}），回退全量 test`) 
      testScope = "all"
    }
  }

  const checks = []
  checks.push(["lint", commands.lint])
  if (level !== "quick") {
    checks.push(["typecheck", commands.typecheck])
    checks.push(["test", testCommand])
  }
  if (level === "full") {
    checks.push(["build", commands.build])
  }

  info(`🚧 Gate (level: ${level}, mode: ${mode}, test-scope: ${testScope}, task: ${taskSlug})`)
  if (testScope === "incremental") {
    info(`🧪 Incremental test files: ${testFiles.join(", ")}`)
  }
  info("")

  const results = []
  let pass = true
  const failedChecks = []

  for (const [name, cmd] of checks) {
    info(`--- ${name} ---`)
    const code = runSafeCommand(cmd, dangerousExecutables)
    if (code === 0) {
      info(`  ✅ ${name}: PASS`)
      results.push({ name, status: "pass" })
    } else {
      info(`  ❌ ${name}: FAIL`)
      results.push({ name, status: "fail" })
      failedChecks.push(name)
      pass = false
    }
  }

  if (level === "quick") {
    info("--- scenario-coverage ---")
    info("  ⏭️ scenario-coverage: SKIPPED (quick mode)")
    results.push({ name: "scenario-coverage", status: "skipped" })
  } else {
    info("--- scenario-coverage ---")
    const scCode = checkScenarioCoverage(taskSlug, null)
    if (scCode === 0) {
      info("  ✅ scenario-coverage: PASS")
      results.push({ name: "scenario-coverage", status: "pass" })
    } else {
      info("  ❌ scenario-coverage: FAIL")
      results.push({ name: "scenario-coverage", status: "fail" })
      failedChecks.push("scenario-coverage")
      pass = false
    }
  }

  info("")
  writeGateEvidence(taskSlug, `${level}:${mode}:${testScope}`, pass, results, metadata)
  patchProgressEntry(path.join(".step", "state.json"), taskSlug, {
    gate_status: pass ? "pass" : "fail",
    gate_level: level,
    gate_mode: mode,
    gate_scope: testScope,
    gate_at: isoNow(),
    ...(pass
      ? { failed_action: "" }
      : {
          failed_action: failedChecks.join("|"),
          summary: `Gate failed at ${failedChecks.join(",")}`,
          next_action: `analyze-${failedChecks[0] || "gate"}-failure`,
        }),
    ...(metadata || {}),
  })

  if (pass) {
    info("✅ Gate PASSED")
    return 0
  }
  info("❌ Gate FAILED")
  return 1
}

function parseScalarValue(v) {
  if (v === "null") return null
  if (v === "true") return true
  if (v === "false") return false
  if (/^-?\d+$/.test(v)) return Number(v)
  return v
}

function setPathValue(obj, dotPath, val) {
  const parts = dotPath.split(".")
  let cur = obj
  for (let i = 0; i < parts.length - 1; i += 1) {
    const p = parts[i]
    if (!isObject(cur[p])) {
      cur[p] = {}
    }
    cur = cur[p]
  }
  cur[parts[parts.length - 1]] = val
}

const DEFAULT_DANGEROUS_EXECUTABLES = [
  "rm",
  "dd",
  "mkfs",
  "shutdown",
  "reboot",
  "poweroff",
  "halt",
  "sudo",
  "chown",
  "chmod",
  "passwd",
  "useradd",
  "usermod",
  "deluser",
  "killall",
  "pkill",
  "launchctl",
]

function resolveProjectRoot() {
  const envRoot = process.env.OPENCODE_PROJECT_DIR
  if (envRoot && fs.existsSync(path.join(envRoot, ".step"))) {
    return envRoot
  }

  let dir = process.cwd()
  while (dir !== "/") {
    if (fs.existsSync(path.join(dir, ".step"))) {
      return dir
    }
    dir = path.dirname(dir)
  }

  if (fs.existsSync("/.step")) {
    return "/"
  }
  return envRoot || process.cwd()
}

function managerPaths() {
  const rootDir = resolveProjectRoot()
  return {
    rootDir,
    stateFile: path.join(rootDir, ".step", "state.json"),
    configFile: path.join(rootDir, ".step", "config.json"),
  }
}

function readJsonSafe(filePath, fallback = null) {
  try {
    if (!fs.existsSync(filePath)) {
      return fallback
    }
    return JSON.parse(fs.readFileSync(filePath, "utf-8"))
  } catch {
    return fallback
  }
}

function getValueByPath(data, dotPath) {
  return getPathValue(data, dotPath)
}

function getConfigValue(config, dotPath) {
  if (!isObject(config)) return undefined
  return getValueByPath(config, dotPath)
}

function getConfigBool(config, dotPath, fallback) {
  const value = getConfigValue(config, dotPath)
  return typeof value === "boolean" ? value : fallback
}

function getModeFromPhase(phase) {
  if (["lite-l1-quick-spec", "lite-l2-execution", "lite-l3-review"].includes(phase)) {
    return "lite"
  }
  return "full"
}

function modeFamily(mode) {
  if (mode === "quick" || mode === "lite") {
    return "lite"
  }
  return "full"
}

function currentModeFromState(state) {
  const m = getValueByPath(state, "session.mode")
  if (["quick", "lite", "full"].includes(m)) {
    return m
  }
  return getModeFromPhase(String(state.current_phase || ""))
}

function phaseForMode(mode) {
  if (mode === "full") return "phase-0-discovery"
  if (mode === "lite" || mode === "quick") return "lite-l1-quick-spec"
  return null
}

function canTransition(from, to) {
  if (from === to) return true
  const allowed = {
    idle: ["phase-0-discovery", "lite-l1-quick-spec"],
    "phase-0-discovery": ["phase-1-prd"],
    "phase-1-prd": ["phase-2-tech-design"],
    "phase-2-tech-design": ["phase-3-planning"],
    "phase-3-planning": ["phase-4-execution"],
    "phase-4-execution": ["phase-5-review"],
    "phase-5-review": ["done"],
    "lite-l1-quick-spec": ["lite-l2-execution"],
    "lite-l2-execution": ["lite-l3-review"],
    "lite-l3-review": ["done"],
  }
  return Array.isArray(allowed[from]) && allowed[from].includes(to)
}

function isPhaseAllowedForTool(phase, tool) {
  if (tool === "Write" || tool === "Edit") {
    return [
      "phase-1-prd",
      "phase-2-tech-design",
      "phase-3-planning",
      "phase-4-execution",
      "phase-5-review",
      "lite-l1-quick-spec",
      "lite-l2-execution",
      "lite-l3-review",
    ].includes(phase)
  }
  if (tool === "Bash" || tool === "Task") {
    return phase !== "idle"
  }
  return true
}

function isPlanningPhase(phase) {
  return ["phase-1-prd", "phase-2-tech-design", "phase-3-planning"].includes(phase)
}

function isExecutionPhase(phase) {
  return ["phase-4-execution", "phase-5-review"].includes(phase)
}

function isReadonlyBashInPlanningPhase(command) {
  if (!command || !String(command).trim()) return false
  const trimmed = String(command).trim()
  if (/^(ls|pwd)(\s+.*)?$/.test(trimmed)) return true
  if (/^git\s+(status|diff|log)(\s+.*)?$/.test(trimmed)) return true
  return false
}

function commandLooksLikeControl(command) {
  if (!command || !String(command).trim()) return true
  const cmd = String(command)
  const tokens = [
    "step-manager.sh doctor",
    "step-manager.sh enter",
    "step-manager.sh transition",
    "step-manager.sh phase-gate",
    "step-manager.sh status-line",
    "step-manager.sh assert-phase",
    "step-manager.sh check-action",
    "step-core.js manager",
  ]
  return tokens.some((token) => cmd.includes(token))
}

function isCommandAllowedWhenIdle(command) {
  if (!command || !String(command).trim()) return true
  const cmd = String(command)
  return [
    "step-manager.sh doctor",
    "step-manager.sh enter",
    "step-manager.sh transition",
    "step-manager.sh status-line",
    "step-core.js manager enter",
    "step-core.js manager transition",
    "step-core.js manager status-line",
  ].some((token) => cmd.includes(token))
}

function isBashCommandAllowedInPhase(phase, command) {
  if (commandLooksLikeControl(command)) return true
  if (["phase-0-discovery", "phase-1-prd", "phase-2-tech-design", "phase-3-planning", "lite-l1-quick-spec"].includes(phase)) {
    return isReadonlyBashInPlanningPhase(command)
  }
  return true
}

function enforceWriteLockForMode(config, mode) {
  const direct = getConfigValue(config, "enforcement.planning_phase_write_lock")
  if (typeof direct === "boolean") {
    return direct
  }
  const family = modeFamily(mode)
  return getConfigBool(config, `enforcement.planning_phase_write_lock.${family}`, family === "full")
}

function requireDispatchForMode(config, mode) {
  const direct = getConfigValue(config, "enforcement.require_dispatch")
  if (typeof direct === "boolean") {
    return direct
  }
  const family = modeFamily(mode)
  return getConfigBool(config, `enforcement.require_dispatch.${family}`, false)
}

function getBypassTools(config) {
  const tools = getConfigValue(config, "enforcement.bypass_tools")
  if (!Array.isArray(tools)) return []
  return tools.map((v) => String(v))
}

function expectedDispatchAgentForPhase(config, phase) {
  const mapping = {
    "phase-0-discovery": "routing.discovery.agent",
    "phase-1-prd": "routing.prd.agent",
    "lite-l1-quick-spec": "routing.lite_spec.agent",
    "phase-2-tech-design": "routing.tech_design.agent",
    "phase-3-planning": "routing.planning.agent",
  }
  const p = mapping[phase]
  if (!p) return ""
  const value = getConfigValue(config, p)
  return typeof value === "string" ? value : ""
}

function firstExecutableFromCommand(command) {
  if (!command || !String(command).trim()) return ""
  const tokens = tokenize(String(command).trim())
  if (tokens.length === 0) return ""

  const base = (raw) => {
    const normalized = String(raw || "").replace(/\\+$/, "")
    const parts = normalized.split("/")
    return parts[parts.length - 1] || normalized
  }

  let i = 0
  let exe = tokens[i] || ""
  if (base(exe) === "env") {
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
  if (base(exe) === "command") {
    i += 1
    exe = tokens[i] || ""
  }
  return base(exe)
}

function dangerousExecutablesFromConfig(config) {
  const configured = getConfigValue(config, "gate.dangerous_executables")
  if (Array.isArray(configured)) {
    return configured.map((v) => String(v))
  }
  return DEFAULT_DANGEROUS_EXECUTABLES
}

function parseIsoTimestamp(value) {
  if (typeof value !== "string" || !value.trim()) return NaN
  const ms = Date.parse(value)
  return Number.isFinite(ms) ? ms : NaN
}

function requireFile(filePath, label) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`❌ 缺少${label}: ${filePath}`)
  }
}

function requireGatePass(rootDir, task, change, options = {}) {
  const evidenceFile = path.join(rootDir, ".step", "changes", change, "evidence", `${task}-gate.json`)
  if (!fs.existsSync(evidenceFile)) {
    throw new Error(`❌ 缺少 gate 证据: ${evidenceFile}`)
  }
  let obj
  try {
    obj = JSON.parse(fs.readFileSync(evidenceFile, "utf-8"))
  } catch {
    throw new Error(`❌ gate 证据解析失败: ${evidenceFile}`)
  }
  if (!(obj && obj.passed === true)) {
    throw new Error("❌ gate 证据未通过")
  }
  if (!(obj && obj.scenario && obj.scenario.passed === true)) {
    throw new Error("❌ scenario 覆盖证据未通过")
  }

  const gateTs = parseIsoTimestamp(obj.timestamp)
  const scenarioTs = parseIsoTimestamp(obj && obj.scenario ? obj.scenario.timestamp : "")
  const requireFresh = options && options.requireFresh === true
  if (requireFresh && (!Number.isFinite(gateTs) || !Number.isFinite(scenarioTs))) {
    throw new Error("❌ gate/scenario 证据缺少可比较时间戳")
  }
  if (Number.isFinite(gateTs) && Number.isFinite(scenarioTs) && gateTs < scenarioTs) {
    throw new Error("❌ gate 证据已过期：scenario 时间晚于 gate 时间，请重跑 gate")
  }
}

function reviewAssessmentFromFile(reviewFile) {
  const text = fs.readFileSync(reviewFile, "utf-8")
  const match = text.match(/Assessment\*\*:\s*([A-Z_]+)/)
  if (!match) return ""
  return String(match[1] || "").trim()
}

function requireReviewPass(rootDir, task, change) {
  const reviewFile = path.join(rootDir, ".step", "changes", change, "evidence", `${task}-review.md`)
  if (!fs.existsSync(reviewFile)) {
    throw new Error(`❌ 缺少review 记录: ${reviewFile}`)
  }
  const assessment = reviewAssessmentFromFile(reviewFile)
  if (assessment !== "APPROVE") {
    throw new Error(`❌ review 未通过（assessment=${assessment || "UNKNOWN"}），请修复后重审`)
  }
}

function evaluateTaskReadiness(rootDir, taskSlug, changeName) {
  const taskFile = path.join(rootDir, ".step", "changes", changeName, "tasks", `${taskSlug}.md`)
  if (!fs.existsSync(taskFile)) {
    return { ready: false, reasons: [`缺少 task 文件: ${taskFile}`], taskFile, summary: null }
  }

  const task = readTask(taskFile)
  const summary = scenarioStatusSummary(task)
  const reasons = []

  if (task.status !== "done") {
    reasons.push("task.status 不是 done")
  }
  if (summary.notRun > 0) {
    reasons.push(`存在 ${summary.notRun} 个 scenario.status=not_run`)
  }
  if (summary.fail > 0) {
    reasons.push(`存在 ${summary.fail} 个 scenario.status=fail`)
  }

  return {
    ready: reasons.length === 0,
    reasons,
    taskFile,
    summary,
  }
}

function requireTaskReady(rootDir, taskSlug, changeName) {
  const result = evaluateTaskReadiness(rootDir, taskSlug, changeName)
  if (!result.ready) {
    throw new Error(`❌ task 未满足完成条件: ${result.reasons.join("; ")}`)
  }
}

function phaseGate(paths, from, to, state) {
  const change = String(state.current_change || "")
  const task = String((state.tasks && state.tasks.current) || "")
  const pair = `${from}->${to}`

  if (pair === "phase-1-prd->phase-2-tech-design") {
    if (!change) throw new Error("❌ current_change 为空，无法进入 phase-2")
    requireFile(path.join(paths.rootDir, ".step", "changes", change, "spec.md"), "spec")
  }
  if (pair === "phase-2-tech-design->phase-3-planning") {
    if (!change) throw new Error("❌ current_change 为空，无法进入 phase-3")
    requireFile(path.join(paths.rootDir, ".step", "changes", change, "design.md"), "design")
  }
  if (pair === "phase-3-planning->phase-4-execution") {
    if (!change) throw new Error("❌ current_change 为空，无法进入 phase-4")
    if (!task) throw new Error("❌ tasks.current 为空，无法进入 phase-4")
    requireFile(path.join(paths.rootDir, ".step", "changes", change, "tasks", `${task}.md`), "task")
  }
  if (pair === "phase-4-execution->phase-5-review") {
    if (!task) throw new Error("❌ tasks.current 为空，无法进入 phase-5")
    requireGatePass(paths.rootDir, task, change)
  }
  if (pair === "phase-5-review->done") {
    if (!task) throw new Error("❌ tasks.current 为空，无法完成")
    if (!change) throw new Error("❌ current_change 为空，无法定位 review 记录")
    requireGatePass(paths.rootDir, task, change, { requireFresh: true })
    requireReviewPass(paths.rootDir, task, change)
    requireTaskReady(paths.rootDir, task, change)
  }
  if (pair === "lite-l1-quick-spec->lite-l2-execution") {
    if (!change) throw new Error("❌ current_change 为空，无法进入 lite-l2")
    if (!task) throw new Error("❌ tasks.current 为空，无法进入 lite-l2")
    requireFile(path.join(paths.rootDir, ".step", "changes", change, "tasks", `${task}.md`), "task")
  }
  if (pair === "lite-l2-execution->lite-l3-review") {
    if (!task) throw new Error("❌ tasks.current 为空，无法进入 lite-l3")
    requireGatePass(paths.rootDir, task, change)
  }
  if (pair === "lite-l3-review->done") {
    if (!task) throw new Error("❌ tasks.current 为空，无法完成")
    if (!change) throw new Error("❌ current_change 为空，无法定位 review 记录")
    requireGatePass(paths.rootDir, task, change, { requireFresh: true })
    requireReviewPass(paths.rootDir, task, change)
    requireTaskReady(paths.rootDir, task, change)
  }
}

function managerRequireStateFile(paths) {
  if (!fs.existsSync(paths.stateFile)) {
    fail(`缺少 state 文件: ${paths.stateFile}`)
  }
}

function managerReadState(paths) {
  managerRequireStateFile(paths)
  return readJson(paths.stateFile)
}

function managerReadConfig(paths) {
  return readJsonSafe(paths.configFile, {}) || {}
}

function managerWriteState(paths, state) {
  writeJsonAtomic(paths.stateFile, state)
}

function managerEnter(paths, args) {
  const mode = args.mode
  if (!mode) fail("enter 需要 --mode quick|lite|full", 2)
  const phase = phaseForMode(mode)
  if (!phase) fail(`不支持的 mode: ${mode}`, 2)

  const state = managerReadState(paths)
  state.current_phase = phase
  state.session = isObject(state.session) ? state.session : {}
  state.session.mode = mode
  state.last_updated = isoNow()
  if (args.change) state.current_change = args.change
  if (args.task) {
    state.tasks = isObject(state.tasks) ? state.tasks : { current: null, upcoming: [] }
    state.tasks.current = args.task
  }
  managerWriteState(paths, state)
  info(`✅ 已进入 STEP: mode=${mode} phase=${phase}`)
}

function managerTransition(paths, args) {
  const to = args.to
  if (!to) fail("transition 需要 --to <phase>", 2)
  const state = managerReadState(paths)
  const from = String(state.current_phase || "")
  if (!canTransition(from, to)) {
    fail(`非法 phase 迁移: ${from} -> ${to}`)
  }
  try {
    phaseGate(paths, from, to, state)
  } catch (err) {
    fail(String(err.message || err))
  }
  state.current_phase = to
  state.last_updated = isoNow()
  managerWriteState(paths, state)
  info(`✅ phase 已迁移: ${from} -> ${to}`)
}

function managerAssertPhase(paths, args) {
  const tool = args.tool
  const command = args.command ? String(args.command) : ""
  if (!tool) fail("assert-phase 需要 --tool", 2)

  const state = managerReadState(paths)
  const config = managerReadConfig(paths)
  const phase = String(state.current_phase || "")
  if (!phase) fail("state 缺少 current_phase")

  if (phase === "idle" && tool === "Bash" && isCommandAllowedWhenIdle(command)) {
    return
  }

  if (!isPhaseAllowedForTool(phase, tool)) {
    fail(`当前 phase=${phase} 不允许工具=${tool}`)
  }

  if (tool === "Bash" && !isBashCommandAllowedInPhase(phase, command)) {
    fail(`当前 phase=${phase} 仅允许流程控制或只读命令，禁止直接执行实现/构建命令`)
  }

  const mode = currentModeFromState(state)
  const writeLockEnabled = enforceWriteLockForMode(config, mode)
  if (writeLockEnabled && (tool === "Write" || tool === "Edit") && isPlanningPhase(phase)) {
    fail(`当前 mode=${mode} phase=${phase} 已启用写锁：请先通过 Task 委派给对应 agent`)
  }
}

function managerAssertDispatch(paths, args) {
  const tool = args.tool
  const agent = args.agent
  if (tool !== "Task") return
  if (!agent) fail("assert-dispatch 需要 --agent", 2)

  const state = managerReadState(paths)
  const config = managerReadConfig(paths)
  const mode = currentModeFromState(state)
  const phase = String(state.current_phase || "")
  const required = requireDispatchForMode(config, mode)
  if (!required) return

  const expected = expectedDispatchAgentForPhase(config, phase)
  if (!expected) return
  if (agent !== expected) {
    fail(`当前 mode=${mode} phase=${phase} 必须委派给 ${expected}, 收到 ${agent}`)
  }
}

function managerCheckAction(paths, args) {
  const tool = args.tool
  const command = args.command ? String(args.command) : ""
  if (!tool) fail("check-action 需要 --tool", 2)
  if (tool !== "Bash") return
  if (!command) return

  const config = managerReadConfig(paths)
  const dangerous = new Set(dangerousExecutablesFromConfig(config))
  const first = firstExecutableFromCommand(command)
  if (first && dangerous.has(first)) {
    fail(`命中危险命令黑名单: ${first}`)
  }
}

function managerStatusLine(paths) {
  if (!fs.existsSync(paths.stateFile)) {
    info("📍 Phase idle | Change: - | Task: -")
    return
  }
  const state = managerReadState(paths)
  const phase = String(state.current_phase || "")
  const change = String(state.current_change || "") || "-"
  const task = String((state.tasks && state.tasks.current) || "") || "-"
  info(`📍 Phase ${phase} | Change: ${change} | Task: ${task}`)
}

function nextArchivePath(baseDir, name) {
  const date = new Date().toISOString().slice(0, 10)
  const base = path.join(baseDir, `${date}-${name}-cancelled`)
  if (!fs.existsSync(base)) return base
  let idx = 1
  while (true) {
    const p = `${base}-${idx}`
    if (!fs.existsSync(p)) return p
    idx += 1
  }
}

function managerCancel(paths, args) {
  const state = managerReadState(paths)
  const phase = String(state.current_phase || "")
  const change = String(args.change || state.current_change || "")

  if (phase === "done") {
    fail("不能取消已完成变更（phase=done）")
  }
  if (phase === "idle" || !change) {
    info("ℹ️ 无活跃变更，跳过取消")
    return
  }

  const changeDir = path.join(paths.rootDir, ".step", "changes", change)
  const archiveDir = path.join(paths.rootDir, ".step", "archive")
  fs.mkdirSync(archiveDir, { recursive: true })
  if (fs.existsSync(changeDir)) {
    fs.renameSync(changeDir, nextArchivePath(archiveDir, change))
  }

  state.current_phase = "idle"
  state.current_change = ""
  state.tasks = isObject(state.tasks) ? state.tasks : { current: null, upcoming: [] }
  state.tasks.current = null
  state.last_updated = isoNow()
  if (!Array.isArray(state.progress_log)) {
    state.progress_log = []
  }
  state.progress_log.unshift({
    date: new Date().toISOString().slice(0, 10),
    task: "",
    summary: `cancelled change: ${change}`,
    next_action: "idle",
  })
  managerWriteState(paths, state)
  info(`✅ 已取消变更: ${change}`)
}

function managerRun(sub, args) {
  const paths = managerPaths()
  if (sub === "enter") {
    managerEnter(paths, args)
    return
  }
  if (sub === "transition") {
    managerTransition(paths, args)
    return
  }
  if (sub === "phase-gate") {
    const from = args.from
    const to = args.to
    if (!from) fail("phase-gate 需要 --from", 2)
    if (!to) fail("phase-gate 需要 --to", 2)
    const state = managerReadState(paths)
    try {
      phaseGate(paths, from, to, state)
    } catch (err) {
      fail(String(err.message || err))
    }
    return
  }
  if (sub === "assert-phase") {
    managerAssertPhase(paths, args)
    return
  }
  if (sub === "assert-dispatch") {
    managerAssertDispatch(paths, args)
    return
  }
  if (sub === "status-line") {
    managerStatusLine(paths)
    return
  }
  if (sub === "check-action") {
    managerCheckAction(paths, args)
    return
  }
  if (sub === "cancel") {
    managerCancel(paths, args)
    return
  }
  fail(`未知 manager 子命令: ${sub}`, 2)
}

function executionAgentsFromConfig(config) {
  const agents = new Set(["step-developer", "step-designer"])
  const execAgent = getConfigValue(config, "routing.execution.agent")
  if (typeof execAgent === "string" && execAgent) agents.add(execAgent)
  const fr = getConfigValue(config, "file_routing")
  if (isObject(fr)) {
    for (const key of Object.keys(fr)) {
      const a = fr[key] && fr[key].agent
      if (typeof a === "string" && a) agents.add(a)
    }
  }
  return agents
}

function applyExecutionDispatchGuard(state, config, tool, agent) {
  const phase = String(state.current_phase || "")
  const mode = currentModeFromState(state)
  const required = requireDispatchForMode(config, mode)
  const bypass = getBypassTools(config)
  if (!required) return
  if (!isExecutionPhase(phase)) return
  if (!(tool === "Write" || tool === "Edit")) return
  if (bypass.includes(tool)) return
  const executionAgents = executionAgentsFromConfig(config)
  if (agent && executionAgents.has(agent)) return
  fail(`当前 mode=${mode} phase=${phase} 已启用 execution dispatch：请通过 Task 委派给 execution agent，再由 subagent 执行 ${tool}`)
}

function parseToolPayload(payloadText) {
  const raw = String(payloadText || "").trim()
  if (!raw) return {}
  let data = {}
  try {
    data = JSON.parse(raw)
  } catch {
    return {}
  }
  const pick = (expr) => {
    const paths = expr.split("|")
    for (const p of paths) {
      const value = getValueByPath(data, p)
      if (value !== undefined && value !== null) {
        return typeof value === "string" ? value : JSON.stringify(value)
      }
    }
    return ""
  }
  return {
    tool: pick("tool_name|toolName|tool.name|tool"),
    command: pick("command|input.command|tool_input.command|arguments.command|params.command"),
    agent: pick("subagent_type|input.subagent_type|tool_input.subagent_type|arguments.subagent_type|params.subagent_type"),
  }
}

function guardRun(args) {
  const paths = managerPaths()
  if (!fs.existsSync(paths.stateFile)) {
    return
  }

  let payloadText = ""
  try {
    if (!process.stdin.isTTY) {
      payloadText = fs.readFileSync(0, "utf-8")
    }
  } catch {
    payloadText = ""
  }

  const payload = parseToolPayload(payloadText)
  const tool = String(args.tool || payload.tool || process.env.OPENCODE_TOOL_NAME || "")
  const command = String(
    args.command || payload.command || process.env.OPENCODE_TOOL_COMMAND || process.env.OPENCODE_COMMAND || "",
  )
  const agent = String(args.agent || payload.agent || "")

  let state = managerReadState(paths)
  const autoEnter = String(args["auto-enter"] || "false") === "true"
  const autoMode = String(args["auto-enter-mode"] || "full")
  if (autoEnter && String(state.current_phase || "") === "idle") {
    const phase = phaseForMode(autoMode) || "phase-0-discovery"
    state.current_phase = phase
    state.current_change = String(state.current_change || "") || "init"
    state.session = isObject(state.session) ? state.session : {}
    state.session.mode = ["full", "lite", "quick"].includes(autoMode) ? autoMode : "full"
    state.last_updated = isoNow()
    managerWriteState(paths, state)
  }

  state = managerReadState(paths)
  const config = managerReadConfig(paths)

  applyExecutionDispatchGuard(state, config, tool, agent)

  if (tool === "Bash") {
    managerAssertPhase(paths, { tool: "Bash", command })
    managerCheckAction(paths, { tool: "Bash", command })
  } else if (tool === "Write" || tool === "Edit") {
    managerAssertPhase(paths, { tool })
  } else if (tool === "Task") {
    managerAssertPhase(paths, { tool: "Task" })
    managerAssertDispatch(paths, { tool: "Task", agent })
  }

  const snapshot = { ...state }
  if (Array.isArray(snapshot.progress_log)) {
    snapshot.progress_log = snapshot.progress_log.slice(0, 2)
  }
  info(JSON.stringify(snapshot, null, 2).split("\n").slice(0, 25).join("\n"))
}

function safeRead(filePath) {
  try {
    return fs.readFileSync(filePath, "utf-8")
  } catch {
    return ""
  }
}

function clipForContext(text, maxLines, maxChars) {
  if (!text) return ""
  let out = String(text)
  if (out.length > maxChars) {
    out = `${out.slice(0, maxChars)}\n\n... [truncated by size]`
  }
  const lines = out.split("\n")
  if (lines.length > maxLines) {
    out = `${lines.slice(0, maxLines).join("\n")}\n\n... [truncated by lines]`
  }
  return out
}

function compactConfigForContext(raw) {
  if (!raw) return ""
  try {
    const cfg = JSON.parse(raw)
    const compact = {
      routing: cfg.routing || {},
      file_routing: cfg.file_routing || {},
      enforcement: cfg.enforcement || {},
      worktree: cfg.worktree || {},
    }
    return JSON.stringify(compact, null, 2)
  } catch {
    return raw
  }
}

function extractSection(markdown, name) {
  const start = `<!-- SECTION:${name} -->`
  const end = `<!-- /SECTION:${name} -->`
  const s = markdown.indexOf(start)
  if (s < 0) return ""
  const e = markdown.indexOf(end, s)
  if (e < 0) return ""
  return markdown.slice(s + start.length, e).trim()
}

function selectSkillSections(skillContent, phase) {
  if (!skillContent) return ""
  const core = extractSection(skillContent, "core-rules")
  const common = extractSection(skillContent, "common")
  if (!core && !common) {
    return skillContent
  }

  const chunks = []
  if (core) chunks.push(core)
  if (common) chunks.push(common)

  const p = String(phase || "")
  if (p.startsWith("phase-0") || p.startsWith("phase-1") || p.startsWith("lite-l1")) {
    const section = extractSection(skillContent, "phase-0-1")
    if (section) chunks.push(section)
  } else if (p.startsWith("phase-2") || p.startsWith("phase-3")) {
    const section = extractSection(skillContent, "phase-2-3")
    if (section) chunks.push(section)
  } else if (p.startsWith("phase-4") || p.startsWith("phase-5") || p.startsWith("lite-l2") || p.startsWith("lite-l3")) {
    const section = extractSection(skillContent, "phase-4-5")
    if (section) chunks.push(section)
  }
  return chunks.join("\n\n")
}

function extractBaselineConstraints(markdown) {
  if (!markdown) return ""
  const match = markdown.match(/(^|\n)##\s+Constraints[\s\S]*?(\n##\s+|$)/)
  if (!match) return markdown
  const body = match[0].replace(/\n##\s+$/, "")
  return `# Baseline\n\n${body.trim()}\n`
}

function hookSessionStart(args) {
  const stateFile = args.state
  if (!stateFile || !fs.existsSync(stateFile)) {
    info(JSON.stringify({ hookSpecificOutput: { hookEventName: "SessionStart", additionalContext: "" } }, null, 2))
    return
  }

  const phase = String(args.phase || "")
  const change = String(args.change || "")
  const task = String(args.task || "")
  const injectTask = String(args["inject-task"] || "false") === "true"
  const warning = String(args.warning || "")
  const skillFile = String(args.skill || "")
  const rootDir = path.dirname(path.dirname(path.resolve(stateFile)))

  const rawState = safeRead(stateFile)
  let stateContent = ""
  try {
    const parsed = JSON.parse(rawState)
    if (isObject(parsed) && Array.isArray(parsed.progress_log)) {
      parsed.progress_log = parsed.progress_log.slice(0, 3)
    }
    stateContent = `${JSON.stringify(parsed, null, 2)}\n`
  } catch {
    const clipped = clipForContext(rawState, 120, 8000)
    stateContent = `⚠️ state.json 解析失败，以下为原始内容片段:\n${clipped}`
  }
  const specContent = change
    ? clipForContext(safeRead(path.join(rootDir, ".step", "changes", change, "spec.md")), 200, 12000)
    : ""
  const findingsContent = change
    ? clipForContext(safeRead(path.join(rootDir, ".step", "changes", change, "findings.md")), 200, 12000)
    : ""
  const taskContent = injectTask && change && task
    ? clipForContext(safeRead(path.join(rootDir, ".step", "changes", change, "tasks", `${task}.md`)), 260, 16000)
    : ""
  const baselineRaw = safeRead(path.join(rootDir, ".step", "baseline.md"))
  const baselineContent = (phase.startsWith("phase-4") || phase.startsWith("phase-5") || phase.startsWith("lite-l2") || phase.startsWith("lite-l3"))
    ? extractBaselineConstraints(baselineRaw)
    : baselineRaw
  const routingContent = clipForContext(
    compactConfigForContext(safeRead(path.join(rootDir, ".step", "config.json"))),
    180,
    10000,
  )
  const skillRaw = safeRead(skillFile)
  const skillContent = selectSkillSections(skillRaw, phase)

  const blocks = []
  if (warning) blocks.push(warning)
  blocks.push("STEP 协议已激活。")
  if (skillContent) blocks.push(`## 核心规则\n${skillContent}`)
  blocks.push(`## state.json\n${stateContent.trim()}`)
  if (specContent) blocks.push(`## 当前变更 spec\n${specContent}`)
  if (findingsContent) blocks.push(`## 当前变更 findings\n${findingsContent}`)
  if (taskContent) blocks.push(`## 当前任务\n${taskContent}`)
  if (baselineContent) blocks.push(`## Baseline\n${baselineContent}`)
  if (routingContent) blocks.push(`## Agent 路由表\n${routingContent}`)
  blocks.push("## 恢复指令\n1. 根据 current_phase 和 routing 表选择对应 agent\n2. 输出状态行: 📍 Phase X | Change: {name} | Task | Status | Next\n3. 从 next_action 继续工作\n4. Phase 4 按 file_routing 的 patterns 决定用 @step-developer 或 @step-designer\n5. 对话结束必须更新 state.json")

  const output = {
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: `<STEP_PROTOCOL>\n${blocks.join("\n\n")}\n</STEP_PROTOCOL>`,
    },
  }
  info(JSON.stringify(output, null, 2))
}

function usage() {
  info("Usage:")
  info("  step-core.js validate state|task|config --file <path>")
  info("  step-core.js manager enter|transition|phase-gate|assert-phase|assert-dispatch|status-line|check-action|cancel [options]")
  info("  step-core.js guard [--tool <ToolName>] [--command <text>] [--agent <subagent>] [--auto-enter true|false] [--auto-enter-mode full|lite|quick]")
  info("  step-core.js hook session-start --state <file> --phase <phase> --change <name> --task <slug> --inject-task true|false --skill <file> [--warning <text>]")
  info("  step-core.js task test-files --task <slug> [--change <name>] [--json]")
  info("  step-core.js task scenarios --task <slug> [--change <name>] [--json]")
  info("  step-core.js task status --file <path> --expected <status>")
  info("  step-core.js task set-status --file <path> --status <planned|in_progress|done|blocked>")
  info("  step-core.js task ready --task <slug> [--change <name>] [--json]")
  info("  step-core.js state set --file <path> --path a.b --value <value>")
  info("  step-core.js state has-progress --file <path> --date <YYYY-MM-DD>")
  info("  step-core.js state validate-failure-log --file <path> --date <YYYY-MM-DD>")
  info("  step-core.js state trim-progress --file <path> --limit <n>")
  info("  step-core.js state patch-progress --file <path> --task <slug> --set k=v[,k=v]")
  info("  step-core.js agents ensure-block --file <path> --begin <text> --end <text> [--content <text>] (content can be stdin)")
  info("  step-core.js scenario check --task <slug> [--change <name>]")
  info("  step-core.js gate test-files --task <slug> [--change <name>] [--json]")
  info("  step-core.js state get --file <path> --path a.b [--json]")
  info("  step-core.js gate run --level quick|lite|full --task <slug> [--mode incremental|all] [--quick-reason <text>] [--escalated true|false] [--escalation-reason <text>] [--config .step/config.json]")
  info("  step-core.js status report [--root .step]")
}

function main() {
  const argv = process.argv.slice(2)
  if (argv.length === 0 || argv[0] === "--help" || argv[0] === "-h") {
    usage()
    process.exit(0)
  }

  const cmd = argv[0]
  const sub = argv[1]
  const args = parseArgs(argv.slice(2))

  if (cmd === "manager") {
    managerRun(sub, args)
    process.exit(0)
  }

  if (cmd === "guard") {
    guardRun(args)
    process.exit(0)
  }

  if (cmd === "hook" && sub === "session-start") {
    hookSessionStart(args)
    process.exit(0)
  }

  if (cmd === "validate") {
    const kind = sub
    const file = args.file
    if (!kind || !file) {
      usage()
      process.exit(1)
    }
    const data = kind === "task" ? readTask(file) : readJson(file)
    let errors = []
    if (kind === "state") errors = validateState(data)
    else if (kind === "task") errors = validateTask(data)
    else if (kind === "config") errors = validateConfig(data)
    else fail(`未知 validate 类型: ${kind}`)

    if (errors.length > 0) {
      fail(`${kind} 校验失败: ${errors.join("; ")}`)
    }
    info(`✅ ${kind} 校验通过: ${file}`)
    process.exit(0)
  }

  if (cmd === "task" && (sub === "test-files" || sub === "scenarios")) {
    const taskSlug = args.task
    if (!taskSlug) fail("缺少 --task")
    const { taskFile } = resolveTaskFile(taskSlug, args.change || null)
    const task = readTask(taskFile)
    const scenarios = flattenScenarios(task)

    if (sub === "scenarios") {
      const data = scenarios.map((s) => s.id)
      if (args.json) info(JSON.stringify(data))
      else data.forEach((id) => info(id))
      process.exit(0)
    }

    const files = unique(scenarios.map((s) => s.test_file)).sort()
    if (args.json) info(JSON.stringify(files))
    else files.forEach((f) => info(f))
    process.exit(0)
  }

  if (cmd === "task" && sub === "status") {
    const file = args.file
    const expected = args.expected
    if (!file || !expected) fail("task status 需要 --file --expected")
    if (!fs.existsSync(file)) {
      process.exit(2)
    }
    let task
    try {
      const raw = fs.readFileSync(file, "utf-8")
      if (file.endsWith(".md")) {
        task = extractTaskJsonFromMarkdown(raw, file)
      } else {
        task = JSON.parse(raw)
      }
    } catch {
      process.exit(2)
    }
    process.exit(task && task.status === expected ? 0 : 1)
  }

  if (cmd === "task" && sub === "set-status") {
    const file = args.file
    const status = args.status
    if (!file || !status) fail("task set-status 需要 --file --status")
    if (!["planned", "in_progress", "done", "blocked"].includes(status)) {
      fail("task set-status 的 status 仅支持 planned/in_progress/done/blocked")
    }
    const task = readTask(file)
    task.status = status
    const errors = validateTask(task)
    if (errors.length > 0) {
      fail(`task 写入后校验失败: ${errors.join("; ")}`)
    }
    writeTaskAtomic(file, task)
    info(`✅ 已更新 task.status: ${file} -> ${status}`)
    process.exit(0)
  }

  if (cmd === "task" && sub === "ready") {
    const taskSlug = args.task
    const change = args.change
    if (!taskSlug || !change) {
      fail("task ready 需要 --task --change")
    }
    const rootDir = resolveProjectRoot()
    const result = evaluateTaskReadiness(rootDir, taskSlug, change)
    if (args.json) {
      info(JSON.stringify(result))
    } else if (result.ready) {
      info(`✅ task ready: ${taskSlug}`)
    } else {
      info(`❌ task not ready: ${taskSlug}`)
      for (const reason of result.reasons) {
        info(`  - ${reason}`)
      }
    }
    process.exit(result.ready ? 0 : 1)
  }

  if (cmd === "state" && sub === "has-progress") {
    const file = args.file
    const date = args.date
    if (!file || !date) fail("state has-progress 需要 --file --date")
    const state = readJson(file)
    const log = Array.isArray(state.progress_log) ? state.progress_log : []
    const ok = log.some((entry) => isObject(entry) && typeof entry.date === "string" && entry.date.includes(date))
    process.exit(ok ? 0 : 1)
  }

  if (cmd === "state" && sub === "validate-failure-log") {
    const file = args.file
    const date = args.date
    if (!file || !date) fail("state validate-failure-log 需要 --file --date")
    const state = readJson(file)
    const log = Array.isArray(state.progress_log) ? state.progress_log : []
    const hit = log.find(
      (entry) =>
        isObject(entry) &&
        typeof entry.date === "string" &&
        entry.date.includes(date) &&
        entry.gate_status === "fail",
    )
    if (!hit) process.exit(0)
    const nextAction = typeof hit.next_action === "string" ? hit.next_action.trim() : ""
    const failedAction = typeof hit.failed_action === "string" ? hit.failed_action.trim() : ""
    if (!nextAction) process.exit(2)
    if (failedAction && nextAction === failedAction) process.exit(3)
    process.exit(0)
  }

  if (cmd === "agents" && sub === "ensure-block") {
    const file = args.file
    const begin = args.begin
    const end = args.end
    if (!file || !begin || !end) fail("agents ensure-block 需要 --file --begin --end")
    let content = typeof args.content === "string" ? args.content : ""
    if (!content) {
      content = readStdinText()
    }
    ensureAgentsBlock(file, begin, end, content)
    info(`✅ 已更新 AGENTS 区块: ${file}`)
    process.exit(0)
  }

  if (cmd === "scenario" && sub === "check") {
    const taskSlug = args.task
    if (!taskSlug) fail("缺少 --task")
    const code = checkScenarioCoverage(taskSlug, args.change || null)
    process.exit(code)
  }

  if (cmd === "gate" && sub === "test-files") {
    const taskSlug = args.task
    if (!taskSlug) fail("缺少 --task")
    const files = getTaskTestFiles(taskSlug, args.change || null)
    if (args.json) info(JSON.stringify(files))
    else files.forEach((f) => info(f))
    process.exit(0)
  }

  if (cmd === "state" && sub === "set") {
    const file = args.file
    const dotPath = args.path
    const rawVal = args.value
    if (!file || !dotPath || rawVal === undefined) {
      fail("state set 需要 --file --path --value")
    }
    if (dotPath === "current_phase") {
      fail("禁止直接写 current_phase，请使用 scripts/step-manager.sh transition --to <phase>")
    }
    const state = readJson(file)
    const errors = validateState(state)
    if (errors.length > 0) {
      fail(`写入前 state 校验失败: ${errors.join("; ")}`)
    }
    const value = parseScalarValue(String(rawVal))
    setPathValue(state, dotPath, value)
    const afterErrors = validateState(state)
    if (afterErrors.length > 0) {
      fail(`写入后 state 校验失败: ${afterErrors.join("; ")}`)
    }
    writeJsonAtomic(file, state)
    info(`✅ 已更新 ${file}: ${dotPath}=${String(rawVal)}`)
    process.exit(0)
  }

  if (cmd === "state" && sub === "get") {
    const file = args.file
    const dotPath = args.path
    if (!file || !dotPath) {
      fail("state get 需要 --file --path")
    }
    const state = readJson(file)
    const value = getPathValue(state, dotPath)
    if (args.json) {
      info(JSON.stringify(value))
    } else if (value === undefined) {
      info("")
    } else if (typeof value === "object") {
      info(JSON.stringify(value))
    } else {
      info(String(value))
    }
    process.exit(0)
  }

  if (cmd === "state" && sub === "trim-progress") {
    const file = args.file
    const limit = Number(args.limit || 3)
    if (!file || !Number.isFinite(limit) || limit <= 0) {
      fail("state trim-progress 需要 --file 和正整数 --limit")
    }
    info(trimProgressForPrint(file, limit))
    process.exit(0)
  }

  if (cmd === "state" && sub === "patch-progress") {
    const file = args.file
    const task = args.task
    const setRaw = args.set
    if (!file || !task || !setRaw) {
      fail("state patch-progress 需要 --file --task --set")
    }
    const fields = {}
    for (const pair of String(setRaw).split(",")) {
      const idx = pair.indexOf("=")
      if (idx < 1) continue
      const k = pair.slice(0, idx).trim()
      const v = pair.slice(idx + 1).trim()
      if (k) fields[k] = v
    }
    patchProgressEntry(file, task, fields)
    info(`✅ 已补写 progress_log: task=${task}`)
    process.exit(0)
  }

  if (cmd === "gate" && sub === "run") {
    const level = args.level
    const task = args.task
    const config = args.config || ".step/config.json"
    const mode = args.mode || "incremental"
    const metadata = {}
    if (args["quick-reason"]) metadata.quick_reason = String(args["quick-reason"])
    if (args.escalated) metadata.escalated = String(args.escalated)
    if (args["escalation-reason"]) metadata.escalation_reason = String(args["escalation-reason"])
    const code = runGate(level, task, config, mode, metadata)
    process.exit(code)
  }

  if (cmd === "status" && sub === "report") {
    const root = args.root || ".step"
    info(renderStatusReport(root))
    process.exit(0)
  }

  usage()
  process.exit(1)
}

main()
