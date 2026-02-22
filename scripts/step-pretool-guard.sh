#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CORE_SCRIPT="${SCRIPT_DIR}/step-core.js"

if [ ! -f "$CORE_SCRIPT" ]; then
  exit 0
fi

if [ ! -f ".step/state.json" ] && [ -z "${OPENCODE_PROJECT_DIR:-}" ]; then
  exit 0
fi

PAYLOAD=""
if [ ! -t 0 ]; then
  set +e
  PAYLOAD=$(cat)
  set -e
fi

if [ -n "$PAYLOAD" ]; then
  printf '%s' "$PAYLOAD" | node "$CORE_SCRIPT" guard \
    --auto-enter "${STEP_AUTO_ENTER:-false}" \
    --auto-enter-mode "${STEP_AUTO_ENTER_MODE:-full}"
else
  node "$CORE_SCRIPT" guard \
    --tool "${OPENCODE_TOOL_NAME:-}" \
    --command "${OPENCODE_TOOL_COMMAND:-${OPENCODE_COMMAND:-}}" \
    --agent "${OPENCODE_SUBAGENT_TYPE:-}" \
    --auto-enter "${STEP_AUTO_ENTER:-false}" \
    --auto-enter-mode "${STEP_AUTO_ENTER_MODE:-full}"
fi

exit 0
