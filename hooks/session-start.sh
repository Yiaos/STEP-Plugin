#!/usr/bin/env bash
# SessionStart hook for STEP protocol plugin

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CORE_SCRIPT="${PLUGIN_ROOT}/scripts/step-core.js"
DOCTOR_SCRIPT="${PLUGIN_ROOT}/scripts/step-manager.sh"

# Plugin 注入已启用时，SessionStart hook 走空输出，避免重复注入。
# 仅在 hooks.json 显式设置 STEP_SESSIONSTART_SKIP_IF_PLUGIN=true 时生效，
# 以避免影响单测（单测会直接调用本脚本）。
if [ "${STEP_SESSIONSTART_SKIP_IF_PLUGIN:-false}" = "true" ]; then
  OPENCODE_PLUGIN_FILE="${OPENCODE_STEP_PLUGIN_FILE:-${HOME}/.config/opencode/plugins/step.js}"
  if [ -f "$OPENCODE_PLUGIN_FILE" ]; then
    cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": ""
  }
}
EOF
    exit 0
  fi
fi

DOCTOR_OUTPUT=""
DOCTOR_EXIT_CODE=0
DOCTOR_FIX_CMD=""
WARNING_MSG=""

if [ -f "$DOCTOR_SCRIPT" ]; then
  set +e
  DOCTOR_OUTPUT=$(bash "$DOCTOR_SCRIPT" doctor 2>&1)
  DOCTOR_EXIT_CODE=$?
  set -e

  if [ "$DOCTOR_EXIT_CODE" -ne 0 ]; then
    while IFS= read -r line; do
      case "$line" in
        修复建议:*)
          DOCTOR_FIX_CMD="${line#修复建议: }"
          break
          ;;
      esac
    done <<< "$DOCTOR_OUTPUT"

    if [ -z "$DOCTOR_FIX_CMD" ]; then
      DOCTOR_FIX_CMD="bash \"${PLUGIN_ROOT}/install.sh\" --force"
    fi
    WARNING_MSG="⚠️ STEP 环境异常，可能导致流程漂移。请优先执行修复命令：${DOCTOR_FIX_CMD}\n\n[step-doctor 输出]\n${DOCTOR_OUTPUT}\n"
  fi
fi

STATE_FILE=""
if [ -f ".step/state.json" ]; then
  STATE_FILE=".step/state.json"
elif [ -n "${OPENCODE_PROJECT_DIR:-}" ] && [ -f "${OPENCODE_PROJECT_DIR}/.step/state.json" ]; then
  STATE_FILE="${OPENCODE_PROJECT_DIR}/.step/state.json"
fi

if [ -z "$STATE_FILE" ]; then
  cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": ""
  }
}
EOF
  exit 0
fi

state_get() {
  local dot_path="$1"
  node "$CORE_SCRIPT" state get --file "$STATE_FILE" --path "$dot_path" 2>/dev/null || true
}

CURRENT_PHASE=$(state_get "current_phase")
CURRENT_CHANGE=$(state_get "current_change")
CURRENT_TASK=$(state_get "tasks.current")
INJECT_TASK="false"
case "$CURRENT_PHASE" in
  phase-4*|phase-5*|lite-l2*|lite-l3*) INJECT_TASK="true" ;;
esac

node "$CORE_SCRIPT" hook session-start \
  --state "$STATE_FILE" \
  --phase "$CURRENT_PHASE" \
  --change "$CURRENT_CHANGE" \
  --task "$CURRENT_TASK" \
  --inject-task "$INJECT_TASK" \
  --skill "${PLUGIN_ROOT}/skills/step/SKILL.md" \
  --warning "$WARNING_MSG"

exit 0
