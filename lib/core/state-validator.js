function isObject(v) {
  return typeof v === "object" && v !== null && !Array.isArray(v)
}

const VALID_STATE_PHASES = new Set([
  "idle",
  "phase-0-discovery",
  "phase-1-prd",
  "phase-2-tech-design",
  "phase-3-planning",
  "phase-4-execution",
  "phase-5-review",
  "lite-l1-quick-spec",
  "lite-l2-execution",
  "lite-l3-review",
  "done",
])

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

  if ("project" in state && typeof state.project !== "string") {
    errors.push("project 必须是字符串")
  }
  if ("current_phase" in state) {
    if (typeof state.current_phase !== "string") {
      errors.push("current_phase 必须是字符串")
    } else if (!VALID_STATE_PHASES.has(state.current_phase)) {
      errors.push("current_phase 不在允许范围")
    }
  }
  if ("current_change" in state && typeof state.current_change !== "string") {
    errors.push("current_change 必须是字符串")
  }
  if ("last_updated" in state && typeof state.last_updated !== "string") {
    errors.push("last_updated 必须是字符串")
  }
  if ("last_agent" in state && typeof state.last_agent !== "string") {
    errors.push("last_agent 必须是字符串")
  }
  if ("last_session_summary" in state && typeof state.last_session_summary !== "string") {
    errors.push("last_session_summary 必须是字符串")
  }

  if ("tasks" in state) {
    if (!isObject(state.tasks)) {
      errors.push("tasks 必须是对象")
    } else {
      if (!Object.prototype.hasOwnProperty.call(state.tasks, "current")) {
        errors.push("tasks.current 缺失")
      } else {
        const t = state.tasks.current
        if (!(t === null || typeof t === "string")) {
          errors.push("tasks.current 必须是 string 或 null")
        }
      }
      if (!Array.isArray(state.tasks.upcoming)) {
        errors.push("tasks.upcoming 必须是数组")
      }
    }
  }

  if (!isObject(state.session)) {
    errors.push("session 必须是对象")
  } else {
    if (typeof state.session.mode !== "string") {
      errors.push("session.mode 必须是字符串")
    } else if (!["full", "lite", "quick"].includes(state.session.mode)) {
      errors.push("session.mode 必须是 full/lite/quick")
    }
  }

  return errors
}

module.exports = {
  VALID_STATE_PHASES,
  validateState,
}
