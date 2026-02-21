#!/bin/bash
# STEP Scenario Coverage Check
# Usage: scenario-check.sh <task-slug> [change-name]
# 验证 task Markdown(JSON代码块) 中每个场景 ID 都有对应的测试
# task-slug 即文件名（不含 .md），如: user-register-api

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CORE_SCRIPT="${SCRIPT_DIR}/step-core.js"

TASK_ID=${1:-""}
CHANGE_NAME=${2:-""}
if [ -z "$TASK_ID" ]; then
  echo "❌ Usage: scenario-check.sh <task-slug> [change-name]"
  echo "   Example: scenario-check.sh user-register-api"
  echo "   Example: scenario-check.sh user-register-api init"
  exit 1
fi

if [ ! -f "$CORE_SCRIPT" ]; then
  echo "❌ 缺少核心工具: $CORE_SCRIPT"
  exit 1
fi

if [ -n "$CHANGE_NAME" ]; then
  node "$CORE_SCRIPT" scenario check --task "$TASK_ID" --change "$CHANGE_NAME"
else
  node "$CORE_SCRIPT" scenario check --task "$TASK_ID"
fi
