#!/bin/bash
# STEP Gate — 质量门禁
# Usage: ./scripts/gate.sh [lite|full|quick|standard] [task-slug] [--all]
#   lite     — lint + typecheck + test + scenario coverage
#   full     — lite + build
# Deprecated:
#   quick    — 已弃用，等价于 lite
#   standard — 已弃用，等价于 lite

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CORE_SCRIPT="${SCRIPT_DIR}/step-core.js"

LEVEL_RAW=${1:-lite}
TASK_ID=${2:-""}
RUN_MODE="incremental"

if [ "${3:-}" = "--all" ]; then
  RUN_MODE="all"
fi

case "$LEVEL_RAW" in
  quick)
    echo "⚠️  gate level 'quick' 已弃用，自动映射到 'lite'"
    LEVEL="lite"
    ;;
  standard)
    echo "⚠️  gate level 'standard' 已弃用，自动映射到 'lite'"
    LEVEL="lite"
    ;;
  lite|full)
    LEVEL="$LEVEL_RAW"
    ;;
  *)
    echo "❌ Invalid level: $LEVEL_RAW"
    echo "Usage: ./scripts/gate.sh [lite|full|quick|standard] [task-slug]"
    exit 2
    ;;
esac

if [ -z "$TASK_ID" ]; then
  echo "❌ gate 必须指定 task slug（例如: ./scripts/gate.sh lite user-register-api）"
  exit 2
fi

if [ ! -f "$CORE_SCRIPT" ]; then
  echo "❌ 缺少核心工具: $CORE_SCRIPT"
  exit 1
fi

node "$CORE_SCRIPT" gate run --level "$LEVEL" --task "$TASK_ID" --mode "$RUN_MODE" --config .step/config.yaml
