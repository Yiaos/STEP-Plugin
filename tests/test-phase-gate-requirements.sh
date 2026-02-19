#!/bin/bash
# T-024 测试：phase-gate 产物约束

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
PASS=0
FAIL=0
TOTAL=0

pass_case() {
  local name="$1"
  echo "  ✅ $name"
  PASS=$((PASS + 1))
}

fail_case() {
  local name="$1"
  echo "  ❌ $name"
  FAIL=$((FAIL + 1))
}

new_sandbox() {
  local dir
  dir=$(mktemp -d)
  mkdir -p "$dir/.step" "$dir/scripts"
  cp "$SCRIPT_DIR/templates/state.json" "$dir/.step/state.json"
  cp "$SCRIPT_DIR/scripts/step-manager.sh" "$dir/scripts/step-manager.sh"
  chmod +x "$dir/scripts/step-manager.sh"
  printf '%s' "$dir"
}

set_state() {
  local file="$1"
  local phase="$2"
  local change="$3"
  local task="$4"
  node -e '
const fs = require("fs")
const file = process.argv[1]
const phase = process.argv[2]
const change = process.argv[3]
const task = process.argv[4]
const s = JSON.parse(fs.readFileSync(file, "utf-8"))
s.current_phase = phase
s.current_change = change || ""
s.tasks = s.tasks || {}
s.tasks.current = task || null
fs.writeFileSync(file, `${JSON.stringify(s, null, 2)}\n`, "utf-8")
' "$file" "$phase" "$change" "$task"
}

echo "=== T-024: phase-gate requirements ==="

# [S-024-01] phase-1->2 缺少 spec 时阻断
TOTAL=$((TOTAL + 1))
{
  box=$(new_sandbox)
  trap 'rm -rf "$box"' EXIT
  mkdir -p "$box/.step/changes/c1"
  set_state "$box/.step/state.json" "phase-1-prd" "c1" ""
  out=$(cd "$box" && bash ./scripts/step-manager.sh transition --to phase-2-tech-design 2>&1)
  code=$?
  rm -rf "$box"
  trap - EXIT
  if [ "$code" -ne 0 ] && printf '%s' "$out" | grep -q '缺少spec'; then
    pass_case "[S-024-01] phase-1->2 缺少 spec 时阻断"
  else
    fail_case "[S-024-01] phase-1->2 缺少 spec 时阻断"
  fi
}

# [S-024-02] phase-1->2 存在 spec 时通过
TOTAL=$((TOTAL + 1))
{
  box=$(new_sandbox)
  trap 'rm -rf "$box"' EXIT
  mkdir -p "$box/.step/changes/c1"
  touch "$box/.step/changes/c1/spec.md"
  set_state "$box/.step/state.json" "phase-1-prd" "c1" ""
  (cd "$box" && bash ./scripts/step-manager.sh transition --to phase-2-tech-design >/dev/null 2>&1)
  code=$?
  rm -rf "$box"
  trap - EXIT
  if [ "$code" -eq 0 ]; then
    pass_case "[S-024-02] phase-1->2 存在 spec 时通过"
  else
    fail_case "[S-024-02] phase-1->2 存在 spec 时通过"
  fi
}

# [S-024-03] phase-4->5 缺少 gate 证据时阻断
TOTAL=$((TOTAL + 1))
{
  box=$(new_sandbox)
  trap 'rm -rf "$box"' EXIT
  mkdir -p "$box/.step/changes/c1/evidence"
  set_state "$box/.step/state.json" "phase-4-execution" "" "demo"
  out=$(cd "$box" && bash ./scripts/step-manager.sh transition --to phase-5-review 2>&1)
  code=$?
  rm -rf "$box"
  trap - EXIT
  if [ "$code" -ne 0 ] && printf '%s' "$out" | grep -q '缺少 gate 证据'; then
    pass_case "[S-024-03] phase-4->5 缺少 gate 证据时阻断"
  else
    fail_case "[S-024-03] phase-4->5 缺少 gate 证据时阻断"
  fi
}

# [S-024-04] phase-4->5 gate+scenario 通过时可迁移
TOTAL=$((TOTAL + 1))
{
  box=$(new_sandbox)
  trap 'rm -rf "$box"' EXIT
  mkdir -p "$box/.step/changes/c1/evidence"
  cat > "$box/.step/changes/c1/evidence/demo-gate.json" <<'EOF'
{
  "task_id": "demo",
  "passed": true,
  "scenario": {
    "passed": true
  }
}
EOF
  set_state "$box/.step/state.json" "phase-4-execution" "c1" "demo"
  (cd "$box" && bash ./scripts/step-manager.sh transition --to phase-5-review >/dev/null 2>&1)
  code=$?
  rm -rf "$box"
  trap - EXIT
  if [ "$code" -eq 0 ]; then
    pass_case "[S-024-04] phase-4->5 gate+scenario 通过时可迁移"
  else
    fail_case "[S-024-04] phase-4->5 gate+scenario 通过时可迁移"
  fi
}

# [S-024-05] phase-5->done 缺少 review 证据时阻断
TOTAL=$((TOTAL + 1))
{
  box=$(new_sandbox)
  trap 'rm -rf "$box"' EXIT
  mkdir -p "$box/.step/changes/c1/evidence"
  set_state "$box/.step/state.json" "phase-5-review" "c1" "demo"
  out=$(cd "$box" && bash ./scripts/step-manager.sh transition --to done 2>&1)
  code=$?
  rm -rf "$box"
  trap - EXIT
  if [ "$code" -ne 0 ] && printf '%s' "$out" | grep -q '缺少review 记录'; then
    pass_case "[S-024-05] phase-5->done 缺少 review 证据时阻断"
  else
    fail_case "[S-024-05] phase-5->done 缺少 review 证据时阻断"
  fi
}

# [S-024-06] phase-5->done 存在 review 证据时通过
TOTAL=$((TOTAL + 1))
{
  box=$(new_sandbox)
  trap 'rm -rf "$box"' EXIT
  mkdir -p "$box/.step/changes/c1/evidence"
  touch "$box/.step/changes/c1/evidence/demo-review.md"
  set_state "$box/.step/state.json" "phase-5-review" "c1" "demo"
  (cd "$box" && bash ./scripts/step-manager.sh transition --to done >/dev/null 2>&1)
  code=$?
  rm -rf "$box"
  trap - EXIT
  if [ "$code" -eq 0 ]; then
    pass_case "[S-024-06] phase-5->done 存在 review 证据时通过"
  else
    fail_case "[S-024-06] phase-5->done 存在 review 证据时通过"
  fi
}

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
