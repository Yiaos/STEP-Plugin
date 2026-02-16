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

function countIndent(line) {
  let n = 0
  while (n < line.length && line[n] === " ") n += 1
  return n
}

function normalizeYamlLines(raw) {
  return raw.replace(/\r\n/g, "\n").split("\n")
}

function stripInlineComment(s) {
  let quote = null
  for (let i = 0; i < s.length; i += 1) {
    const ch = s[i]
    if (quote) {
      if (ch === quote) quote = null
      continue
    }
    if (ch === '"' || ch === "'") {
      quote = ch
      continue
    }
    if (ch === "#" && (i === 0 || /\s/.test(s[i - 1]))) {
      return s.slice(0, i).trimEnd()
    }
  }
  return s
}

function parseScalar(raw) {
  const s = stripInlineComment(raw).trim()
  if (s === "") return ""
  if (s === "null") return null
  if (s === "true") return true
  if (s === "false") return false
  if (s === "[]") return []
  if (s === "{}") return {}
  if (/^-?\d+$/.test(s)) return Number(s)
  if ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'"))) {
    return s.slice(1, -1)
  }
  return s
}

function splitKeyValue(content) {
  const idx = content.indexOf(":")
  if (idx < 0) return null
  const key = content.slice(0, idx).trim()
  const value = content.slice(idx + 1)
  return { key, value }
}

function parseBlock(lines, startIndex, indent) {
  let i = startIndex
  while (i < lines.length) {
    const line = lines[i]
    const trimmed = line.trim()
    if (trimmed === "" || trimmed.startsWith("#")) {
      i += 1
      continue
    }
    const ind = countIndent(line)
    if (ind < indent) return { value: null, next: i }
    if (ind > indent) {
      fail(`YAML 缩进错误，第 ${i + 1} 行`) 
    }
    const content = line.slice(indent)
    if (content.startsWith("- ")) {
      return parseList(lines, i, indent)
    }
    return parseMap(lines, i, indent)
  }
  return { value: null, next: i }
}

function parseMap(lines, startIndex, indent) {
  const out = {}
  let i = startIndex
  while (i < lines.length) {
    const line = lines[i]
    const trimmed = line.trim()
    if (trimmed === "" || trimmed.startsWith("#")) {
      i += 1
      continue
    }
    const ind = countIndent(line)
    if (ind < indent) break
    if (ind > indent) {
      fail(`YAML map 缩进错误，第 ${i + 1} 行`)
    }
    const content = line.slice(indent)
    if (content.startsWith("- ")) break
    const kv = splitKeyValue(content)
    if (!kv) {
      fail(`YAML 键值格式错误，第 ${i + 1} 行`) 
    }
    const { key, value } = kv
    if (value.trim() === "") {
      const nested = parseBlock(lines, i + 1, indent + 2)
      out[key] = nested.value === null ? {} : nested.value
      i = nested.next
    } else {
      out[key] = parseScalar(value)
      i += 1
    }
  }
  return { value: out, next: i }
}

function parseList(lines, startIndex, indent) {
  const out = []
  let i = startIndex
  while (i < lines.length) {
    const line = lines[i]
    const trimmed = line.trim()
    if (trimmed === "" || trimmed.startsWith("#")) {
      i += 1
      continue
    }
    const ind = countIndent(line)
    if (ind < indent) break
    if (ind > indent) {
      fail(`YAML list 缩进错误，第 ${i + 1} 行`)
    }
    const content = line.slice(indent)
    if (!content.startsWith("- ")) break
    const itemRest = content.slice(2)
    if (itemRest.trim() === "") {
      const nested = parseBlock(lines, i + 1, indent + 2)
      out.push(nested.value)
      i = nested.next
      continue
    }

    const kv = splitKeyValue(itemRest)
    if (!kv) {
      out.push(parseScalar(itemRest))
      i += 1
      continue
    }

    const item = {}
    if (kv.value.trim() === "") {
      const nestedVal = parseBlock(lines, i + 1, indent + 4)
      item[kv.key] = nestedVal.value
      i = nestedVal.next
    } else {
      item[kv.key] = parseScalar(kv.value)
      i += 1
    }

    if (i < lines.length) {
      const tail = parseMap(lines, i, indent + 2)
      if (tail.next > i && tail.value && Object.keys(tail.value).length > 0) {
        Object.assign(item, tail.value)
        i = tail.next
      }
    }
    out.push(item)
  }
  return { value: out, next: i }
}

function parseYaml(raw) {
  const lines = normalizeYamlLines(raw)
  const parsed = parseBlock(lines, 0, 0)
  return parsed.value
}

function dumpScalar(value) {
  if (value === null) return "null"
  if (typeof value === "boolean") return value ? "true" : "false"
  if (typeof value === "number") return String(value)
  const s = String(value)
  if (s === "" || /^[-?:\[\]{}#,!]|\s|:$/.test(s) || s.includes(": ")) {
    return JSON.stringify(s)
  }
  return s
}

function dumpYaml(value, indent = 0) {
  const pad = " ".repeat(indent)
  if (Array.isArray(value)) {
    return value
      .map((item) => {
        if (isObject(item) || Array.isArray(item)) {
          const nested = dumpYaml(item, indent + 2)
          return `${pad}-\n${nested}`
        }
        return `${pad}- ${dumpScalar(item)}`
      })
      .join("\n")
  }
  if (isObject(value)) {
    return Object.keys(value)
      .map((key) => {
        const v = value[key]
        if (isObject(v) || Array.isArray(v)) {
          const nested = dumpYaml(v, indent + 2)
          return `${pad}${key}:\n${nested}`
        }
        return `${pad}${key}: ${dumpScalar(v)}`
      })
      .join("\n")
  }
  return `${pad}${dumpScalar(value)}`
}

function readYaml(filePath) {
  ensureFile(filePath)
  const raw = fs.readFileSync(filePath, "utf-8")
  try {
    return parseYaml(raw)
  } catch (err) {
    fail(`YAML 解析失败: ${filePath} (${String(err)})`)
  }
}

function writeYamlAtomic(filePath, data) {
  const tmpPath = `${filePath}.tmp-${process.pid}`
  const content = `${dumpYaml(data)}\n`
  fs.writeFileSync(tmpPath, content, "utf-8")
  fs.renameSync(tmpPath, filePath)
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

function resolveTaskFile(taskSlug, changeName) {
  const byChange = (change) => path.join(".step", "changes", change, "tasks", `${taskSlug}.yaml`)

  if (changeName) {
    const p = byChange(changeName)
    if (!fs.existsSync(p)) {
      fail(`未找到任务文件: ${p}`)
    }
    return { taskFile: p, change: changeName }
  }

  if (fs.existsSync(".step/state.yaml")) {
    const state = readYaml(".step/state.yaml")
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

function flattenScenarios(task) {
  const out = []
  if (Array.isArray(task.scenarios)) {
    for (const s of task.scenarios) {
      if (s && s.id && s.test_file) {
        out.push({ id: s.id, test_file: s.test_file })
      }
    }
    return out
  }
  if (isObject(task.scenarios)) {
    for (const key of Object.keys(task.scenarios)) {
      const arr = task.scenarios[key]
      if (!Array.isArray(arr)) {
        continue
      }
      for (const s of arr) {
        if (s && s.id && s.test_file) {
          out.push({ id: s.id, test_file: s.test_file })
        }
      }
    }
  }
  return out
}

function unique(arr) {
  return [...new Set(arr)]
}

function ensureEvidenceDir() {
  fs.mkdirSync(path.join(".step", "evidence"), { recursive: true })
}

function isoNow() {
  return new Date().toISOString().replace(/\.\d{3}Z$/, "Z")
}

function writeScenarioEvidence(taskSlug, change, taskFile, total, covered) {
  ensureEvidenceDir()
  const evidencePath = path.join(".step", "evidence", `${taskSlug}-scenario.json`)
  const cov = total > 0 ? Math.floor((covered * 100) / total) : 0
  const payload = {
    task_id: taskSlug,
    change,
    task_file: taskFile,
    timestamp: isoNow(),
    total,
    covered,
    coverage_pct: cov,
    passed: cov === 100,
  }
  fs.writeFileSync(evidencePath, `${JSON.stringify(payload, null, 2)}\n`, "utf-8")
}

function checkScenarioCoverage(taskSlug, changeName) {
  const { taskFile, change } = resolveTaskFile(taskSlug, changeName)
  const task = readYaml(taskFile)
  const scenarios = flattenScenarios(task)

  let total = 0
  let covered = 0
  const missing = []

  for (const s of scenarios) {
    total += 1
    if (!fs.existsSync(s.test_file)) {
      missing.push(`${s.id} not found in ${s.test_file}`)
      continue
    }
    const content = fs.readFileSync(s.test_file, "utf-8")
    if (content.includes(`[${s.id}]`)) {
      covered += 1
    } else {
      missing.push(`${s.id} not found in ${s.test_file}`)
    }
  }

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
  const cfg = readYaml(configPath)
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
  ensureEvidenceDir()
  const payload = {
    task_id: taskSlug,
    level,
    timestamp: isoNow(),
    passed: pass,
    results,
    ...(metadata || {}),
  }
  const evidencePath = path.join(".step", "evidence", `${taskSlug}-gate.json`)
  fs.writeFileSync(evidencePath, `${JSON.stringify(payload, null, 2)}\n`, "utf-8")
  info(`📄 Evidence saved: ${evidencePath}`)
}

function todayUTC() {
  return new Date().toISOString().slice(0, 10)
}

function patchProgressEntry(filePath, taskSlug, fields) {
  if (!fs.existsSync(filePath)) return
  const state = readYaml(filePath)
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
  writeYamlAtomic(filePath, state)
}

function trimProgressForPrint(filePath, limit) {
  const state = readYaml(filePath)
  if (isObject(state) && Array.isArray(state.progress_log)) {
    state.progress_log = state.progress_log.slice(0, limit)
  }
  return dumpYaml(state)
}

function renderStatusReport(root = ".step") {
  const statePath = path.join(root, "state.yaml")
  if (!fs.existsSync(statePath)) {
    return "STEP 未初始化（缺少 .step/state.yaml）"
  }
  const state = readYaml(statePath)
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
        if (!tf.endsWith(".yaml")) continue
        total += 1
        const t = readYaml(path.join(taskDir, tf))
        if (t && t.status === "done") done += 1
      }
    }
  }

  const evidenceDir = path.join(root, "evidence")
  let gatePass = 0
  let gateFail = 0
  if (fs.existsSync(evidenceDir)) {
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
  const task = readYaml(taskFile)
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

  const segments = splitChain(baseCommand)
  if (segments.length !== 1) {
    return { command: baseCommand, applied: false, reason: "multi-segment-command" }
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

  for (const [name, cmd] of checks) {
    info(`--- ${name} ---`)
    const code = runSafeCommand(cmd, dangerousExecutables)
    if (code === 0) {
      info(`  ✅ ${name}: PASS`)
      results.push({ name, status: "pass" })
    } else {
      info(`  ❌ ${name}: FAIL`)
      results.push({ name, status: "fail" })
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
      pass = false
    }
  }

  info("")
  writeGateEvidence(taskSlug, `${level}:${mode}:${testScope}`, pass, results, metadata)
  patchProgressEntry(path.join(".step", "state.yaml"), taskSlug, {
    gate_status: pass ? "pass" : "fail",
    gate_level: level,
    gate_mode: mode,
    gate_scope: testScope,
    gate_at: isoNow(),
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

function usage() {
  info("Usage:")
  info("  step-core.js validate state|task|config --file <path>")
  info("  step-core.js task test-files --task <slug> [--change <name>] [--json]")
  info("  step-core.js task scenarios --task <slug> [--change <name>] [--json]")
  info("  step-core.js state set --file <path> --path a.b --value <value>")
  info("  step-core.js state trim-progress --file <path> --limit <n>")
  info("  step-core.js state patch-progress --file <path> --task <slug> --set k=v[,k=v]")
  info("  step-core.js scenario check --task <slug> [--change <name>]")
  info("  step-core.js gate test-files --task <slug> [--change <name>] [--json]")
  info("  step-core.js gate run --level quick|lite|full --task <slug> [--mode incremental|all] [--quick-reason <text>] [--escalated true|false] [--escalation-reason <text>] [--config .step/config.yaml]")
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

  if (cmd === "validate") {
    const kind = sub
    const file = args.file
    if (!kind || !file) {
      usage()
      process.exit(1)
    }
    const data = readYaml(file)
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
    const task = readYaml(taskFile)
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
    const state = readYaml(file)
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
    writeYamlAtomic(file, state)
    info(`✅ 已更新 ${file}: ${dotPath}=${String(rawVal)}`)
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
    const config = args.config || ".step/config.yaml"
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
