#!/usr/bin/env bash
# SessionStart hook for STEP protocol plugin
# 自动检测 .step/state.json 并注入项目状态到 LLM 上下文

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

DOCTOR_SCRIPT="${PLUGIN_ROOT}/scripts/step-manager.sh"
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

    WARNING_MSG="⚠️ STEP 环境异常，可能导致流程漂移。请优先执行修复命令：${DOCTOR_FIX_CMD}\n\n[step-doctor 输出]\n${DOCTOR_OUTPUT}\n\n"
  fi
fi

# 查找 .step/state.json
STATE_FILE=""
if [ -f ".step/state.json" ]; then
  STATE_FILE=".step/state.json"
elif [ -n "${OPENCODE_PROJECT_DIR:-}" ] && [ -f "${OPENCODE_PROJECT_DIR}/.step/state.json" ]; then
  STATE_FILE="${OPENCODE_PROJECT_DIR}/.step/state.json"
fi

# 没有 STEP 项目，不注入上下文
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

# 转义 JSON
escape_for_json() {
  local input="$1"
  local output=""
  local i char
  for (( i=0; i<${#input}; i++ )); do
    char="${input:$i:1}"
    case "$char" in
      $'\\') output+='\\\\' ;;
      '"') output+='\"' ;;
      $'\n') output+='\\n' ;;
      $'\r') output+='\\r' ;;
      $'\t') output+='\\t' ;;
      *) output+="$char" ;;
    esac
  done
  printf '%s' "$output"
}

# 读取核心文件（progress_log 仅注入最近 3 条）
CORE_SCRIPT="${PLUGIN_ROOT}/scripts/step-core.js"
if [ -f "$CORE_SCRIPT" ]; then
  STATE_CONTENT=$(node "$CORE_SCRIPT" state trim-progress --file "$STATE_FILE" --limit 3 2>/dev/null || cat "$STATE_FILE" 2>&1 || echo "Error reading state.json")
else
  STATE_CONTENT=$(cat "$STATE_FILE" 2>&1 || echo "Error reading state.json")
fi

state_get() {
  local dot_path="$1"
  if [ -f "$CORE_SCRIPT" ]; then
    node "$CORE_SCRIPT" state get --file "$STATE_FILE" --path "$dot_path" 2>/dev/null || true
  else
    printf ''
  fi
}

CURRENT_PHASE=$(state_get "current_phase")

# 读取当前变更和任务
TASK_CONTENT=""
CURRENT_CHANGE=$(state_get "current_change")
CURRENT_TASK=$(state_get "tasks.current")
INJECT_TASK="false"
case "$CURRENT_PHASE" in
  phase-4*|phase-5*|lite-l2*|lite-l3*) INJECT_TASK="true" ;;
esac

if [ "$INJECT_TASK" = "true" ] && [ -n "$CURRENT_CHANGE" ] && [ -n "$CURRENT_TASK" ]; then
  TASK_PATH=".step/changes/${CURRENT_CHANGE}/tasks/${CURRENT_TASK}.md"
  if [ -f "$TASK_PATH" ]; then
    TASK_CONTENT=$(cat "$TASK_PATH" 2>&1 || echo "")
  fi
fi

# 读取当前变更的 spec.md
SPEC_CONTENT=""
if [ -n "$CURRENT_CHANGE" ] && [ -f ".step/changes/${CURRENT_CHANGE}/spec.md" ]; then
  SPEC_CONTENT=$(cat ".step/changes/${CURRENT_CHANGE}/spec.md" 2>&1 || echo "")
fi

# 读取当前变更的 findings.md（如果存在）
FINDINGS_CONTENT=""
if [ -n "$CURRENT_CHANGE" ] && [ -f ".step/changes/${CURRENT_CHANGE}/findings.md" ]; then
  FINDINGS_CONTENT=$(cat ".step/changes/${CURRENT_CHANGE}/findings.md" 2>&1 || echo "")
fi

# 读取 baseline
BASELINE_CONTENT=""
if [ -f ".step/baseline.md" ]; then
  BASELINE_CONTENT=$(cat ".step/baseline.md" 2>&1 || echo "")
fi

# 读取完整 config.json（routing + file_routing + gate，完整注入避免截断风险）
ROUTING_CONTENT=""
if [ -f ".step/config.json" ]; then
  ROUTING_CONTENT=$(cat ".step/config.json" 2>&1 || echo "")
fi

# 读取 SKILL.md 核心规则
SKILL_CONTENT=""
if [ -f "${PLUGIN_ROOT}/skills/step/SKILL.md" ]; then
  SKILL_CONTENT=$(cat "${PLUGIN_ROOT}/skills/step/SKILL.md" 2>&1 || echo "")
fi

STATE_ESC=$(escape_for_json "$STATE_CONTENT")
TASK_ESC=$(escape_for_json "$TASK_CONTENT")
SPEC_ESC=$(escape_for_json "$SPEC_CONTENT")
FINDINGS_ESC=$(escape_for_json "$FINDINGS_CONTENT")
BASELINE_ESC=$(escape_for_json "$BASELINE_CONTENT")
ROUTING_ESC=$(escape_for_json "$ROUTING_CONTENT")
SKILL_ESC=$(escape_for_json "$SKILL_CONTENT")
WARNING_ESC=$(escape_for_json "$WARNING_MSG")

FINDINGS_SECTION_ESC=""
if [ -n "$FINDINGS_CONTENT" ]; then
  FINDINGS_SECTION_ESC="\n\n## 当前变更 findings\n${FINDINGS_ESC}"
fi

TASK_SECTION_ESC=""
if [ "$INJECT_TASK" = "true" ]; then
  TASK_SECTION_ESC="\n\n## 当前任务\n${TASK_ESC}"
fi

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "<STEP_PROTOCOL>\n${WARNING_ESC}STEP 协议已激活。\n\n## 核心规则\n${SKILL_ESC}\n\n## state.json\n${STATE_ESC}\n\n## 当前变更 spec\n${SPEC_ESC}${FINDINGS_SECTION_ESC}${TASK_SECTION_ESC}\n\n## Baseline\n${BASELINE_ESC}\n\n## Agent 路由表\n${ROUTING_ESC}\n\n## 恢复指令\n1. 根据 current_phase 和 routing 表选择对应 agent\n2. 输出状态行: 📍 Phase X | Change: {name} | Task | Status | Next\n3. 从 next_action 继续工作\n4. Phase 4 按 file_routing 的 patterns 决定用 @step-developer 或 @step-designer\n5. 对话结束必须更新 state.json\n</STEP_PROTOCOL>"
  }
}
EOF

exit 0
