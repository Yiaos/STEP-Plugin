#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CORE_SCRIPT="${SCRIPT_DIR}/step-core.js"
DOCTOR_SCRIPT="${SCRIPT_DIR}/step-doctor.sh"

if [ "${1:-}" = "doctor" ]; then
  shift
  if [ ! -f "$DOCTOR_SCRIPT" ]; then
    echo "❌ 缺少 doctor 脚本: $DOCTOR_SCRIPT"
    exit 1
  fi
  bash "$DOCTOR_SCRIPT" "$@"
  exit $?
fi

if [ ! -f "$CORE_SCRIPT" ]; then
  echo "❌ 缺少核心工具: $CORE_SCRIPT"
  exit 1
fi

node "$CORE_SCRIPT" manager "$@"
