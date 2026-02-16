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

function pythonCommand() {
  const cands = ["python3", "python"]
  for (const cmd of cands) {
    const p = spawnSync(cmd, ["-V"], { stdio: "ignore" })
    if (p.status === 0) {
      return cmd
    }
  }
  fail("未找到 python3/python，无法解析 YAML")
}

function readYaml(filePath) {
  ensureFile(filePath)
  const py = pythonCommand()
  const script = [
    "import json,sys,yaml",
    "p=sys.argv[1]",
    "with open(p,'r',encoding='utf-8') as f:",
    "  data=yaml.safe_load(f)",
    "print(json.dumps(data, ensure_ascii=False))",
  ].join("\n")
  const out = spawnSync(py, ["-c", script, filePath], { encoding: "utf-8" })
  if (out.status !== 0) {
    fail(`YAML 解析失败: ${filePath}\n${out.stderr || out.stdout}`)
  }
  try {
    return JSON.parse(out.stdout)
  } catch (err) {
    fail(`YAML 转 JSON 失败: ${filePath} (${String(err)})`)
  }
}

function writeYamlAtomic(filePath, data) {
  const py = pythonCommand()
  const tmpPath = `${filePath}.tmp-${process.pid}`
  const script = [
    "import json,sys,yaml",
    "payload=json.loads(sys.argv[1])",
    "target=sys.argv[2]",
    "with open(target,'w',encoding='utf-8') as f:",
    "  yaml.safe_dump(payload, f, sort_keys=False, allow_unicode=True)",
  ].join("\n")
  const payload = JSON.stringify(data)
  const out = spawnSync(py, ["-c", script, payload, tmpPath], { encoding: "utf-8" })
  if (out.status !== 0) {
    fail(`YAML 写入失败: ${filePath}\n${out.stderr || out.stdout}`)
  }
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

function sanitizeTokens(tokens) {
  if (tokens.length === 0) {
    fail("空命令段")
  }
  const allowExecutables = new Set([
    "pnpm",
    "npm",
    "node",
    "python3",
    "python",
    "bash",
    "sh",
    "yarn",
    "bun",
    "npx",
    "vitest",
    "jest",
    "echo",
  ])
  const exe = tokens[0]
  if (!allowExecutables.has(exe)) {
    fail(`命令不在白名单中: ${exe}`)
  }
  const banned = /[;|><`$]/
  for (const t of tokens) {
    if (banned.test(t)) {
      fail(`命令包含非法字符: ${t}`)
    }
  }
}

function runSafeCommand(command) {
  const segments = splitChain(command)
  for (const seg of segments) {
    const tokens = tokenize(seg)
    sanitizeTokens(tokens)
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
  }
}

function writeGateEvidence(taskSlug, level, pass, results) {
  ensureEvidenceDir()
  const payload = {
    task_id: taskSlug,
    level,
    timestamp: isoNow(),
    passed: pass,
    results,
  }
  const evidencePath = path.join(".step", "evidence", `${taskSlug}-gate.json`)
  fs.writeFileSync(evidencePath, `${JSON.stringify(payload, null, 2)}\n`, "utf-8")
  info(`📄 Evidence saved: ${evidencePath}`)
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

function runGate(level, taskSlug, configPath, mode) {
  if (!(level === "lite" || level === "full")) {
    fail(`不支持的 gate 级别: ${level}`)
  }
  if (!taskSlug) {
    fail("gate 需要 task slug，例如: gate run --level lite --task user-register-api", 2)
  }
  if (!(mode === "incremental" || mode === "all")) {
    fail(`不支持的 gate mode: ${mode}`)
  }

  const commands = getGateCommands(configPath)
  const testFiles = getTaskTestFiles(taskSlug, null)
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

  const checks = [
    ["lint", commands.lint],
    ["typecheck", commands.typecheck],
    ["test", testCommand],
  ]
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
    const code = runSafeCommand(cmd)
    if (code === 0) {
      info(`  ✅ ${name}: PASS`)
      results.push({ name, status: "pass" })
    } else {
      info(`  ❌ ${name}: FAIL`)
      results.push({ name, status: "fail" })
      pass = false
    }
  }

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

  info("")
  writeGateEvidence(taskSlug, `${level}:${mode}:${testScope}`, pass, results)

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
  info("  step-core.js scenario check --task <slug> [--change <name>]")
  info("  step-core.js gate test-files --task <slug> [--change <name>] [--json]")
  info("  step-core.js gate run --level lite|full --task <slug> [--mode incremental|all] [--config .step/config.yaml]")
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

  if (cmd === "gate" && sub === "run") {
    const level = args.level
    const task = args.task
    const config = args.config || ".step/config.yaml"
    const mode = args.mode || "incremental"
    const code = runGate(level, task, config, mode)
    process.exit(code)
  }

  usage()
  process.exit(1)
}

main()
