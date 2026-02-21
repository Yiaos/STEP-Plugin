#!/bin/bash
# STEP Gate — 质量门禁
# Usage: gate.sh [quick|lite|full] [task-slug] [--all] [--quick-reason <text>] [--escalated true|false] [--escalation-reason <text>]
#   quick    — 轻量门禁（lint + 记录证据）
#   lite     — lint + typecheck + test + scenario coverage
#   full     — lite + build

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CORE_SCRIPT="${SCRIPT_DIR}/step-core.js"
DOCTOR_SCRIPT="${SCRIPT_DIR}/step-manager.sh"

LEVEL_RAW=${1:-lite}
TASK_ID=${2:-""}
RUN_MODE="incremental"
QUICK_REASON="${STEP_QUICK_REASON:-}"
ESCALATED="${STEP_ESCALATED:-}"
ESCALATION_REASON="${STEP_ESCALATION_REASON:-}"

if [ "$#" -ge 3 ]; then
  set -- "${@:3}"
else
  set --
fi
while [ "$#" -gt 0 ]; do
  case "$1" in
    --all)
      RUN_MODE="all"
      shift
      ;;
    --quick-reason)
      QUICK_REASON="${2:-}"
      shift 2
      ;;
    --escalated)
      ESCALATED="${2:-}"
      shift 2
      ;;
    --escalation-reason)
      ESCALATION_REASON="${2:-}"
      shift 2
      ;;
    *)
      echo "❌ Unknown option: $1"
      exit 2
      ;;
  esac
done

case "$LEVEL_RAW" in
  quick|lite|full)
    LEVEL="$LEVEL_RAW"
    ;;
  *)
    echo "❌ Invalid level: $LEVEL_RAW"
    echo "Usage: gate.sh [quick|lite|full] [task-slug]"
    exit 2
    ;;
esac

if [ -z "$TASK_ID" ]; then
  echo "❌ gate 必须指定 task slug（例如: gate.sh lite user-register-api）"
  exit 2
fi

if [ -f "$DOCTOR_SCRIPT" ]; then
  set +e
  DOCTOR_OUTPUT=$(bash "$DOCTOR_SCRIPT" doctor 2>&1)
  DOCTOR_STATUS=$?
  set -e

  if [ "$DOCTOR_STATUS" -ne 0 ]; then
    printf '\033[31m❌ STEP 环境不完整，拒绝执行 Gate\033[0m\n' >&2
    if [ -n "$DOCTOR_OUTPUT" ]; then
      printf '%s\n' "$DOCTOR_OUTPUT" >&2
    fi
    exit 1
  fi
fi

if [ ! -f "$CORE_SCRIPT" ]; then
  echo "❌ 缺少核心工具: $CORE_SCRIPT"
  exit 1
fi

CMD=(node "$CORE_SCRIPT" gate run --level "$LEVEL" --task "$TASK_ID" --mode "$RUN_MODE" --config .step/config.json)
[ -n "$QUICK_REASON" ] && CMD+=(--quick-reason "$QUICK_REASON")
[ -n "$ESCALATED" ] && CMD+=(--escalated "$ESCALATED")
[ -n "$ESCALATION_REASON" ] && CMD+=(--escalation-reason "$ESCALATION_REASON")

"${CMD[@]}"
