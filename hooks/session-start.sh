#!/usr/bin/env bash
# SessionStart hook for STEP protocol plugin
# 自动检测 .step/state.yaml 并注入项目状态到 LLM 上下文

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 查找 .step/state.yaml
STATE_FILE=""
if [ -f ".step/state.yaml" ]; then
  STATE_FILE=".step/state.yaml"
elif [ -n "${OPENCODE_PROJECT_DIR:-}" ] && [ -f "${OPENCODE_PROJECT_DIR}/.step/state.yaml" ]; then
  STATE_FILE="${OPENCODE_PROJECT_DIR}/.step/state.yaml"
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

# 读取核心文件
STATE_CONTENT=$(cat "$STATE_FILE" 2>&1 || echo "Error reading state.yaml")

# 读取当前任务（slug 格式，如 user-register-api）
TASK_CONTENT=""
CURRENT_TASK=$(grep -E "^\s+id:" "$STATE_FILE" 2>/dev/null | head -1 | sed 's/.*id: *//' | tr -d ' "'"'" || true)
if [ -n "$CURRENT_TASK" ] && [ -f ".step/tasks/${CURRENT_TASK}.yaml" ]; then
  TASK_CONTENT=$(cat ".step/tasks/${CURRENT_TASK}.yaml" 2>&1 || echo "")
fi

# 读取 baseline
BASELINE_CONTENT=""
if [ -f ".step/baseline.md" ]; then
  BASELINE_CONTENT=$(head -50 ".step/baseline.md" 2>&1 || echo "")
fi

# 读取 config.yaml 的 routing 部分（让 LLM 每次会话都看到路由表）
ROUTING_CONTENT=""
if [ -f ".step/config.yaml" ]; then
  ROUTING_CONTENT=$(grep -A 50 '^routing:' ".step/config.yaml" 2>/dev/null | head -30 || echo "")
fi

# 读取 SKILL.md 核心规则
SKILL_CONTENT=""
if [ -f "${PLUGIN_ROOT}/skills/step/SKILL.md" ]; then
  SKILL_CONTENT=$(cat "${PLUGIN_ROOT}/skills/step/SKILL.md" 2>&1 || echo "")
fi

STATE_ESC=$(escape_for_json "$STATE_CONTENT")
TASK_ESC=$(escape_for_json "$TASK_CONTENT")
BASELINE_ESC=$(escape_for_json "$BASELINE_CONTENT")
ROUTING_ESC=$(escape_for_json "$ROUTING_CONTENT")
SKILL_ESC=$(escape_for_json "$SKILL_CONTENT")

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "<STEP_PROTOCOL>\nSTEP 协议已激活。\n\n## 核心规则\n${SKILL_ESC}\n\n## state.yaml\n${STATE_ESC}\n\n## 当前任务\n${TASK_ESC}\n\n## Baseline (摘要)\n${BASELINE_ESC}\n\n## Agent 路由表\n${ROUTING_ESC}\n\n## 恢复指令\n1. 根据 current_phase 和 routing 表选择对应 agent\n2. 输出状态行: 📍 Phase X | Task | Status | Next\n3. 从 next_action 继续工作\n4. Phase 4 按 file_routing 的 patterns 决定用 @step-developer 或 @step-designer\n5. 对话结束必须更新 state.yaml\n</STEP_PROTOCOL>"
  }
}
EOF

exit 0
