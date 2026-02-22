function getPathValue(obj, dotPath) {
  if (!dotPath) return obj
  const parts = String(dotPath).split(".")
  let cur = obj
  for (const p of parts) {
    if (cur == null || !(p in cur)) return undefined
    cur = cur[p]
  }
  return cur
}

function getConfigValue(config, dotPath) {
  if (typeof config !== "object" || config === null || Array.isArray(config)) {
    return undefined
  }
  return getPathValue(config, dotPath)
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
  const m = getPathValue(state, "session.mode")
  if (["quick", "lite", "full"].includes(m)) {
    return m
  }
  return getModeFromPhase(String((state && state.current_phase) || ""))
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

module.exports = {
  getPathValue,
  getConfigValue,
  getModeFromPhase,
  modeFamily,
  currentModeFromState,
  phaseForMode,
  canTransition,
  isPhaseAllowedForTool,
  isPlanningPhase,
  isExecutionPhase,
  isReadonlyBashInPlanningPhase,
  commandLooksLikeControl,
  isCommandAllowedWhenIdle,
  isBashCommandAllowedInPhase,
  enforceWriteLockForMode,
  requireDispatchForMode,
  getBypassTools,
  expectedDispatchAgentForPhase,
}
