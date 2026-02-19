#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
MANAGER_SCRIPT="${SCRIPT_DIR}/step-manager.sh"

if [ ! -f "$MANAGER_SCRIPT" ]; then
  exit 0
fi

PAYLOAD=""
if [ ! -t 0 ]; then
  set +e
  PAYLOAD=$(cat)
  set -e
fi

extract_field() {
  local key_expr="$1"
  node -e '
const fs = require("fs")
const input = fs.readFileSync(0, "utf-8")
if (!input.trim()) process.exit(0)
let data
try { data = JSON.parse(input) } catch { process.exit(0) }
const expr = process.argv[1]
const paths = expr.split("|")
for (const p of paths) {
  const segs = p.split(".")
  let cur = data
  let ok = true
  for (const s of segs) {
    if (cur && Object.prototype.hasOwnProperty.call(cur, s)) {
      cur = cur[s]
    } else {
      ok = false
      break
    }
  }
  if (ok && cur !== undefined && cur !== null) {
    process.stdout.write(typeof cur === "string" ? cur : JSON.stringify(cur))
    process.exit(0)
  }
}
' "$key_expr"
}

TOOL_NAME=""
COMMAND_TEXT=""
if [ -n "$PAYLOAD" ]; then
  TOOL_NAME=$(printf '%s' "$PAYLOAD" | extract_field "tool_name|toolName|tool.name|tool")
  COMMAND_TEXT=$(printf '%s' "$PAYLOAD" | extract_field "command|input.command|tool_input.command|arguments.command|params.command")
fi

[ -z "$TOOL_NAME" ] && TOOL_NAME="${OPENCODE_TOOL_NAME:-${TOOL_NAME:-}}"
[ -z "$COMMAND_TEXT" ] && COMMAND_TEXT="${OPENCODE_TOOL_COMMAND:-${OPENCODE_COMMAND:-${COMMAND_TEXT:-}}}"

if [ "$TOOL_NAME" = "Bash" ]; then
  bash "$MANAGER_SCRIPT" assert-phase --tool Bash --command "$COMMAND_TEXT"
  bash "$MANAGER_SCRIPT" check-action --tool Bash --command "$COMMAND_TEXT"
elif [ "$TOOL_NAME" = "Write" ] || [ "$TOOL_NAME" = "Edit" ]; then
  bash "$MANAGER_SCRIPT" assert-phase --tool "$TOOL_NAME"
fi

exit 0
