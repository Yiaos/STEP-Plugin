/**
 * STEP plugin for OpenCode
 *
 * Injects STEP SessionStart context via system prompt transform.
 * Uses step-core hook session-start to keep a single context builder.
 */

import fs from "fs"
import path from "path"
import os from "os"
import { spawnSync } from "child_process"
import { fileURLToPath } from "url"

const __dirname = path.dirname(fileURLToPath(import.meta.url))

function normalizePath(p, homeDir) {
  if (!p || typeof p !== "string") return null
  let normalized = p.trim()
  if (!normalized) return null
  if (normalized.startsWith("~/")) {
    normalized = path.join(homeDir, normalized.slice(2))
  } else if (normalized === "~") {
    normalized = homeDir
  }
  return path.resolve(normalized)
}

function findProjectRoot(candidates) {
  const seen = new Set()
  for (const candidate of candidates) {
    let dir = candidate
    while (dir && !seen.has(dir)) {
      seen.add(dir)
      const stateFile = path.join(dir, ".step", "state.json")
      if (fs.existsSync(stateFile)) {
        return dir
      }
      const parent = path.dirname(dir)
      if (parent === dir) break
      dir = parent
    }
  }
  return null
}

function stateSnapshot(stateFile) {
  try {
    const raw = fs.readFileSync(stateFile, "utf8")
    const parsed = JSON.parse(raw)
    const phase = typeof parsed.current_phase === "string" ? parsed.current_phase : ""
    const change = typeof parsed.current_change === "string" ? parsed.current_change : ""
    const task = parsed && parsed.tasks && typeof parsed.tasks.current === "string" ? parsed.tasks.current : ""
    return { phase, change, task }
  } catch {
    return { phase: "", change: "", task: "" }
  }
}

function shouldInjectTask(phase) {
  const p = String(phase || "")
  return p.startsWith("phase-4") || p.startsWith("phase-5") || p.startsWith("lite-l2") || p.startsWith("lite-l3")
}

function sessionContextFromCore(pluginRoot, projectRoot) {
  const coreScript = path.join(pluginRoot, "scripts", "step-core.js")
  const skillFile = path.join(pluginRoot, "skills", "step", "SKILL.md")
  const stateFile = path.join(projectRoot, ".step", "state.json")
  if (!fs.existsSync(coreScript) || !fs.existsSync(skillFile) || !fs.existsSync(stateFile)) {
    return ""
  }

  const snapshot = stateSnapshot(stateFile)
  const phase = snapshot.phase
  const change = snapshot.change
  const task = snapshot.task
  const injectTask = shouldInjectTask(phase) ? "true" : "false"

  const result = spawnSync(
    "node",
    [
      coreScript,
      "hook",
      "session-start",
      "--state",
      stateFile,
      "--phase",
      phase,
      "--change",
      change,
      "--task",
      task,
      "--inject-task",
      injectTask,
      "--skill",
      skillFile,
    ],
    { encoding: "utf8", cwd: projectRoot },
  )

  if (result.status !== 0) return ""
  const stdout = String(result.stdout || "").trim()
  if (!stdout) return ""

  try {
    const payload = JSON.parse(stdout)
    const context = payload && payload.hookSpecificOutput && payload.hookSpecificOutput.additionalContext
    return typeof context === "string" ? context : ""
  } catch {
    return ""
  }
}

export const StepPlugin = async ({ directory }) => {
  const homeDir = os.homedir()
  const pluginRoot = path.resolve(__dirname, "../..")
  const envProjectDir = normalizePath(process.env.OPENCODE_PROJECT_DIR, homeDir)

  return {
    "experimental.chat.system.transform": async (_input, output) => {
      const projectRoot = findProjectRoot([
        normalizePath(directory, homeDir),
        envProjectDir,
      ])
      if (!projectRoot) return

      const context = sessionContextFromCore(pluginRoot, projectRoot)
      if (!context) return

      ;(output.system ||= []).push(context)
    },
  }
}
