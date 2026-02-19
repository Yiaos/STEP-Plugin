#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
STATE_FILE="${ROOT_DIR}/.step/state.json"
CONFIG_FILE="${ROOT_DIR}/.step/config.json"
DOCTOR_SCRIPT="${SCRIPT_DIR}/step-doctor.sh"

DEFAULT_DANGEROUS=(
  rm dd mkfs shutdown reboot poweroff halt sudo chown chmod passwd useradd usermod deluser killall pkill launchctl
)

usage() {
  cat <<'EOF'
Usage:
  scripts/step-manager.sh doctor
  scripts/step-manager.sh enter --mode quick|lite|full [--change <name>] [--task <slug>]
  scripts/step-manager.sh phase-gate --from <phase> --to <phase>
  scripts/step-manager.sh transition --to <phase>
  scripts/step-manager.sh assert-phase --tool <ToolName> [--command "..."]
  scripts/step-manager.sh status-line
  scripts/step-manager.sh check-action --tool <ToolName> [--command "..."]
EOF
}

phase_for_mode() {
  case "$1" in
    full)
      echo "phase-0-discovery"
      ;;
    lite|quick)
      echo "lite-l1-quick-spec"
      ;;
    *)
      return 1
      ;;
  esac
}

require_state_file() {
  if [ ! -f "$STATE_FILE" ]; then
    echo "❌ 缺少 state 文件: $STATE_FILE"
    return 1
  fi
}

get_state_field() {
  local path="$1"
  node -e '
const fs = require("fs")
const file = process.argv[1]
const dotPath = process.argv[2]
const state = JSON.parse(fs.readFileSync(file, "utf-8"))
let cur = state
for (const p of dotPath.split(".")) {
  if (cur && Object.prototype.hasOwnProperty.call(cur, p)) cur = cur[p]
  else { cur = undefined; break }
}
if (cur === undefined || cur === null) process.stdout.write("")
else if (typeof cur === "object") process.stdout.write(JSON.stringify(cur))
else process.stdout.write(String(cur))
' "$STATE_FILE" "$path"
}

set_state_fields() {
  node -e '
const fs = require("fs")
const file = process.argv[1]
const pairs = process.argv.slice(2)
const state = JSON.parse(fs.readFileSync(file, "utf-8"))
for (const pair of pairs) {
  const idx = pair.indexOf("=")
  if (idx < 1) continue
  const key = pair.slice(0, idx)
  const raw = pair.slice(idx + 1)
  let val = raw
  if (raw === "null") val = null
  else if (raw === "true") val = true
  else if (raw === "false") val = false
  else if (/^-?\d+$/.test(raw)) val = Number(raw)
  const segs = key.split(".")
  let cur = state
  for (let i = 0; i < segs.length - 1; i += 1) {
    const s = segs[i]
    if (!cur[s] || typeof cur[s] !== "object") cur[s] = {}
    cur = cur[s]
  }
  cur[segs[segs.length - 1]] = val
}
fs.writeFileSync(file, `${JSON.stringify(state, null, 2)}\n`, "utf-8")
' "$STATE_FILE" "$@"
}

is_phase_allowed_for_tool() {
  local phase="$1"
  local tool="$2"
  case "$tool" in
    Write|Edit)
      case "$phase" in
        phase-1-prd|phase-2-tech-design|phase-3-planning|phase-4-execution|phase-5-review|lite-l1-quick-spec|lite-l2-execution|lite-l3-review)
          return 0
          ;;
        *)
          return 1
          ;;
      esac
      ;;
    Bash)
      case "$phase" in
        idle)
          return 1
          ;;
        *)
          return 0
          ;;
      esac
      ;;
    *)
      return 0
      ;;
  esac
}

is_command_allowed_when_idle() {
  local command="$1"
  [ -z "$command" ] && return 0
  if [[ "$command" == *"step-manager.sh doctor"* ]] || \
     [[ "$command" == *"step-manager.sh enter"* ]] || \
     [[ "$command" == *"step-manager.sh transition"* ]] || \
     [[ "$command" == *"step-manager.sh status-line"* ]]; then
    return 0
  fi
  return 1
}

can_transition() {
  local from="$1"
  local to="$2"
  [ "$from" = "$to" ] && return 0
  case "$from" in
    idle)
      case "$to" in
        phase-0-discovery|lite-l1-quick-spec)
          return 0
          ;;
      esac
      ;;
    phase-0-discovery)
      [ "$to" = "phase-1-prd" ] && return 0
      ;;
    phase-1-prd)
      [ "$to" = "phase-2-tech-design" ] && return 0
      ;;
    phase-2-tech-design)
      [ "$to" = "phase-3-planning" ] && return 0
      ;;
    phase-3-planning)
      [ "$to" = "phase-4-execution" ] && return 0
      ;;
    phase-4-execution)
      [ "$to" = "phase-5-review" ] && return 0
      ;;
    phase-5-review)
      [ "$to" = "done" ] && return 0
      ;;
    lite-l1-quick-spec)
      [ "$to" = "lite-l2-execution" ] && return 0
      ;;
    lite-l2-execution)
      [ "$to" = "lite-l3-review" ] && return 0
      ;;
    lite-l3-review)
      [ "$to" = "done" ] && return 0
      ;;
  esac
  return 1
}

require_file() {
  local file="$1"
  local label="$2"
  if [ ! -f "$file" ]; then
    echo "❌ 缺少${label}: $file"
    return 1
  fi
  return 0
}

require_gate_pass() {
  local task="$1"
  local evidence_file="${ROOT_DIR}/.step/evidence/${task}-gate.json"
  if [ ! -f "$evidence_file" ]; then
    echo "❌ 缺少 gate 证据: $evidence_file"
    return 1
  fi
  node -e '
const fs = require("fs")
const file = process.argv[1]
let obj
try {
  obj = JSON.parse(fs.readFileSync(file, "utf-8"))
} catch {
  console.error(`❌ gate 证据解析失败: ${file}`)
  process.exit(1)
}
const gatePass = obj && obj.passed === true
const scenarioPass = obj && obj.scenario && obj.scenario.passed === true
if (!gatePass) {
  console.error("❌ gate 证据未通过")
  process.exit(1)
}
if (!scenarioPass) {
  console.error("❌ scenario 覆盖证据未通过")
  process.exit(1)
}
' "$evidence_file"
}

require_review_record() {
  local change="$1"
  local task="$2"
  if [ -z "$change" ]; then
    echo "❌ current_change 为空，无法定位 review 记录"
    return 1
  fi
  local review_file="${ROOT_DIR}/.step/changes/${change}/reviews/${task}.md"
  require_file "$review_file" "review 记录" || return 1
}

phase_gate() {
  local from="$1"
  local to="$2"
  local change task
  change=$(get_state_field "current_change")
  task=$(get_state_field "tasks.current")

  case "${from}->${to}" in
    "phase-1-prd->phase-2-tech-design")
      [ -z "$change" ] && {
        echo "❌ current_change 为空，无法进入 phase-2"
        return 1
      }
      require_file "${ROOT_DIR}/.step/changes/${change}/spec.md" "spec" || return 1
      ;;
    "phase-2-tech-design->phase-3-planning")
      [ -z "$change" ] && {
        echo "❌ current_change 为空，无法进入 phase-3"
        return 1
      }
      require_file "${ROOT_DIR}/.step/changes/${change}/design.md" "design" || return 1
      ;;
    "phase-3-planning->phase-4-execution")
      [ -z "$change" ] && {
        echo "❌ current_change 为空，无法进入 phase-4"
        return 1
      }
      [ -z "$task" ] && {
        echo "❌ tasks.current 为空，无法进入 phase-4"
        return 1
      }
      require_file "${ROOT_DIR}/.step/changes/${change}/tasks/${task}.md" "task" || return 1
      ;;
    "phase-4-execution->phase-5-review")
      [ -z "$task" ] && {
        echo "❌ tasks.current 为空，无法进入 phase-5"
        return 1
      }
      require_gate_pass "$task" || return 1
      ;;
    "phase-5-review->done")
      [ -z "$task" ] && {
        echo "❌ tasks.current 为空，无法完成"
        return 1
      }
      require_review_record "$change" "$task" || return 1
      ;;
    "lite-l1-quick-spec->lite-l2-execution")
      [ -z "$change" ] && {
        echo "❌ current_change 为空，无法进入 lite-l2"
        return 1
      }
      [ -z "$task" ] && {
        echo "❌ tasks.current 为空，无法进入 lite-l2"
        return 1
      }
      require_file "${ROOT_DIR}/.step/changes/${change}/tasks/${task}.md" "task" || return 1
      ;;
    "lite-l2-execution->lite-l3-review")
      [ -z "$task" ] && {
        echo "❌ tasks.current 为空，无法进入 lite-l3"
        return 1
      }
      require_gate_pass "$task" || return 1
      ;;
    "lite-l3-review->done")
      [ -z "$task" ] && {
        echo "❌ tasks.current 为空，无法完成"
        return 1
      }
      require_review_record "$change" "$task" || return 1
      ;;
    *)
      ;;
  esac
  return 0
}

contains_word() {
  local needle="$1"
  shift
  local x=""
  for x in "$@"; do
    [ "$x" = "$needle" ] && return 0
  done
  return 1
}

load_dangerous_list() {
  if [ -f "$CONFIG_FILE" ]; then
    node -e '
const fs = require("fs")
const file = process.argv[1]
const defaults = process.argv.slice(2)
try {
  const cfg = JSON.parse(fs.readFileSync(file, "utf-8"))
  const arr = cfg && cfg.gate && Array.isArray(cfg.gate.dangerous_executables)
    ? cfg.gate.dangerous_executables.map((v) => String(v))
    : defaults
  process.stdout.write(arr.join("\n"))
} catch {
  process.stdout.write(defaults.join("\n"))
}
' "$CONFIG_FILE" "${DEFAULT_DANGEROUS[@]}"
  else
    printf '%s\n' "${DEFAULT_DANGEROUS[@]}"
  fi
}

check_bash_command() {
  local command="$1"
  [ -z "$command" ] && return 0

  local first
  first=$(node -e '
const src = process.argv[1] || ""
const tokens = src.trim().match(/"[^"]*"|'"'"'[^'"'"']*'"'"'|\S+/g) || []
const clean = (s) => {
  if (!s) return ""
  if ((s.startsWith("\"") && s.endsWith("\"")) || (s.startsWith("'") && s.endsWith("'"))) {
    return s.slice(1, -1)
  }
  return s
}

let i = 0
let exe = clean(tokens[i] || "")
const base = (s) => {
  const normalized = String(s || "").replace(/\\+$/, "")
  const parts = normalized.split("/")
  return parts[parts.length - 1] || normalized
}

if (base(exe) === "env") {
  i += 1
  while (i < tokens.length) {
    const t = clean(tokens[i])
    if (/^[A-Za-z_][A-Za-z0-9_]*=/.test(t)) {
      i += 1
      continue
    }
    exe = t
    break
  }
}

if (base(exe) === "command") {
  i += 1
  exe = clean(tokens[i] || "")
}

process.stdout.write(base(exe))
' "$command")

  [ -z "$first" ] && return 0

  local dangerous
  dangerous=$(load_dangerous_list)
  local list=()
  local line=""
  while IFS= read -r line; do
    [ -n "$line" ] && list+=("$line")
  done <<< "$dangerous"

  if contains_word "$first" "${list[@]}"; then
    echo "❌ 命中危险命令黑名单: $first"
    return 1
  fi
  return 0
}

doctor() {
  if [ ! -f "$DOCTOR_SCRIPT" ]; then
    echo "❌ 缺少 doctor 脚本: $DOCTOR_SCRIPT"
    return 1
  fi
  bash "$DOCTOR_SCRIPT"
}

enter() {
  require_state_file
  local mode=""
  local change=""
  local task=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --mode)
        mode="${2:-}"
        shift 2
        ;;
      --change)
        change="${2:-}"
        shift 2
        ;;
      --task)
        task="${2:-}"
        shift 2
        ;;
      *)
        echo "❌ Unknown option: $1"
        return 2
        ;;
    esac
  done
  if [ -z "$mode" ]; then
    echo "❌ enter 需要 --mode quick|lite|full"
    return 2
  fi

  local phase
  phase=$(phase_for_mode "$mode") || {
    echo "❌ 不支持的 mode: $mode"
    return 2
  }

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local pairs=("current_phase=$phase" "last_updated=$now")
  if [ -n "$change" ]; then
    pairs+=("current_change=$change")
  fi
  if [ -n "$task" ]; then
    pairs+=("tasks.current=$task")
  fi
  set_state_fields "${pairs[@]}"
  echo "✅ 已进入 STEP: mode=$mode phase=$phase"
}

transition() {
  require_state_file
  local to=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --to)
        to="${2:-}"
        shift 2
        ;;
      *)
        echo "❌ Unknown option: $1"
        return 2
        ;;
    esac
  done
  [ -z "$to" ] && {
    echo "❌ transition 需要 --to <phase>"
    return 2
  }

  local from
  from=$(get_state_field "current_phase")
  if ! can_transition "$from" "$to"; then
    echo "❌ 非法 phase 迁移: $from -> $to"
    return 1
  fi
  if ! phase_gate "$from" "$to"; then
    return 1
  fi
  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  set_state_fields "current_phase=$to" "last_updated=$now"
  echo "✅ phase 已迁移: $from -> $to"
}

phase_gate_cmd() {
  local from=""
  local to=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --from)
        from="${2:-}"
        shift 2
        ;;
      --to)
        to="${2:-}"
        shift 2
        ;;
      *)
        echo "❌ Unknown option: $1"
        return 2
        ;;
    esac
  done
  [ -z "$from" ] && {
    echo "❌ phase-gate 需要 --from"
    return 2
  }
  [ -z "$to" ] && {
    echo "❌ phase-gate 需要 --to"
    return 2
  }
  phase_gate "$from" "$to"
}

status_line() {
  require_state_file
  local phase change task
  phase=$(get_state_field "current_phase")
  change=$(get_state_field "current_change")
  task=$(get_state_field "tasks.current")
  [ -z "$change" ] && change="-"
  [ -z "$task" ] && task="-"
  echo "📍 Phase ${phase} | Change: ${change} | Task: ${task}"
}

assert_phase() {
  require_state_file
  local tool=""
  local command=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --tool)
        tool="${2:-}"
        shift 2
        ;;
      --command)
        command="${2:-}"
        shift 2
        ;;
      *)
        echo "❌ Unknown option: $1"
        return 2
        ;;
    esac
  done

  [ -z "$tool" ] && {
    echo "❌ assert-phase 需要 --tool"
    return 2
  }

  local phase
  phase=$(get_state_field "current_phase")
  if [ -z "$phase" ]; then
    echo "❌ state 缺少 current_phase"
    return 1
  fi

  if [ "$phase" = "idle" ] && [ "$tool" = "Bash" ] && is_command_allowed_when_idle "$command"; then
    return 0
  fi

  if ! is_phase_allowed_for_tool "$phase" "$tool"; then
    echo "❌ 当前 phase=$phase 不允许工具=$tool"
    return 1
  fi
  return 0
}

check_action() {
  local tool=""
  local command=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --tool)
        tool="${2:-}"
        shift 2
        ;;
      --command)
        command="${2:-}"
        shift 2
        ;;
      *)
        echo "❌ Unknown option: $1"
        return 2
        ;;
    esac
  done

  if [ -z "$tool" ]; then
    echo "❌ check-action 需要 --tool"
    return 2
  fi

  case "$tool" in
    Bash)
      check_bash_command "$command"
      ;;
    *)
      return 0
      ;;
  esac
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    doctor)
      shift
      doctor "$@"
      ;;
    enter)
      shift
      enter "$@"
      ;;
    transition)
      shift
      transition "$@"
      ;;
    phase-gate)
      shift
      phase_gate_cmd "$@"
      ;;
    assert-phase)
      shift
      assert_phase "$@"
      ;;
    status-line)
      shift
      status_line "$@"
      ;;
    check-action)
      shift
      check_action "$@"
      ;;
    *)
      usage
      return 2
      ;;
  esac
}

main "$@"
