#!/bin/bash
# T-023 测试：STEP phase 强制执行

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

new_box() {
  local dir
  dir=$(mktemp -d)
  mkdir -p "$dir/.step" "$dir/scripts"
  cp "$SCRIPT_DIR/templates/state.json" "$dir/.step/state.json"
  cp "$SCRIPT_DIR/scripts/step-manager.sh" "$dir/scripts/step-manager.sh"
  chmod +x "$dir/scripts/step-manager.sh"
  printf '%s' "$dir"
}

echo "=== T-023: STEP phase enforcement ==="

# [S-023-01] idle 阶段阻断 Write
TOTAL=$((TOTAL + 1))
{
  box=$(new_box)
  trap 'rm -rf "$box"' EXIT
  node -e 'const fs=require("fs");const f=process.argv[1];const s=JSON.parse(fs.readFileSync(f,"utf-8"));s.current_phase="idle";fs.writeFileSync(f,JSON.stringify(s,null,2)+"\n","utf-8");' "$box/.step/state.json"
  out=$(cd "$box" && bash ./scripts/step-manager.sh assert-phase --tool Write 2>&1)
  code=$?
  rm -rf "$box"
  trap - EXIT
  if [ "$code" -ne 0 ] && printf '%s' "$out" | grep -q '不允许工具=Write'; then
    pass_case "[S-023-01] idle 阶段阻断 Write"
  else
    fail_case "[S-023-01] idle 阶段阻断 Write"
  fi
}

# [S-023-02] 迁移到 phase-1 后允许 Write
TOTAL=$((TOTAL + 1))
{
  box=$(new_box)
  trap 'rm -rf "$box"' EXIT
  (cd "$box" && bash ./scripts/step-manager.sh enter --mode full --change init >/dev/null 2>&1)
  (cd "$box" && bash ./scripts/step-manager.sh transition --to phase-1-prd >/dev/null 2>&1)
  (cd "$box" && bash ./scripts/step-manager.sh assert-phase --tool Write >/dev/null 2>&1)
  code=$?
  rm -rf "$box"
  trap - EXIT
  if [ "$code" -eq 0 ]; then
    pass_case "[S-023-02] 迁移到 phase-1 后允许 Write"
  else
    fail_case "[S-023-02] 迁移到 phase-1 后允许 Write"
  fi
}

# [S-023-03] 非法 phase 跳转被拒绝
TOTAL=$((TOTAL + 1))
{
  box=$(new_box)
  trap 'rm -rf "$box"' EXIT
  (cd "$box" && bash ./scripts/step-manager.sh enter --mode full --change init >/dev/null 2>&1)
  out=$(cd "$box" && bash ./scripts/step-manager.sh transition --to phase-4-execution 2>&1)
  code=$?
  rm -rf "$box"
  trap - EXIT
  if [ "$code" -ne 0 ] && printf '%s' "$out" | grep -q '非法 phase 迁移'; then
    pass_case "[S-023-03] 非法 phase 跳转被拒绝"
  else
    fail_case "[S-023-03] 非法 phase 跳转被拒绝"
  fi
}

# [S-023-04] 禁止 step-core 直接写 current_phase
TOTAL=$((TOTAL + 1))
{
  box=$(mktemp -d)
  trap 'rm -rf "$box"' EXIT
  mkdir -p "$box/.step"
  cp "$SCRIPT_DIR/templates/state.json" "$box/.step/state.json"
  cp "$SCRIPT_DIR/scripts/step-core.js" "$box/step-core.js"
  chmod +x "$box/step-core.js"
  out=$(node "$box/step-core.js" state set --file "$box/.step/state.json" --path current_phase --value phase-4-execution 2>&1)
  code=$?
  rm -rf "$box"
  trap - EXIT
  if [ "$code" -ne 0 ] && printf '%s' "$out" | grep -q '禁止直接写 current_phase'; then
    pass_case "[S-023-04] 禁止 step-core 直接写 current_phase"
  else
    fail_case "[S-023-04] 禁止 step-core 直接写 current_phase"
  fi
}

# [S-023-05] pretool guard 在 idle 阻断 Write
TOTAL=$((TOTAL + 1))
{
  box=$(mktemp -d)
  trap 'rm -rf "$box"' EXIT
  mkdir -p "$box/.step" "$box/scripts"
  cp "$SCRIPT_DIR/templates/state.json" "$box/.step/state.json"
  cp "$SCRIPT_DIR/scripts/step-manager.sh" "$box/scripts/step-manager.sh"
  cp "$SCRIPT_DIR/scripts/step-pretool-guard.sh" "$box/scripts/step-pretool-guard.sh"
  chmod +x "$box/scripts/step-manager.sh" "$box/scripts/step-pretool-guard.sh"
  node -e 'const fs=require("fs");const f=process.argv[1];const s=JSON.parse(fs.readFileSync(f,"utf-8"));s.current_phase="idle";fs.writeFileSync(f,JSON.stringify(s,null,2)+"\n","utf-8");' "$box/.step/state.json"
  out=$(cd "$box" && OPENCODE_TOOL_NAME=Write bash ./scripts/step-pretool-guard.sh 2>&1)
  code=$?
  rm -rf "$box"
  trap - EXIT
  if [ "$code" -ne 0 ] && printf '%s' "$out" | grep -q '不允许工具=Write'; then
    pass_case "[S-023-05] pretool guard 在 idle 阻断 Write"
  else
    fail_case "[S-023-05] pretool guard 在 idle 阻断 Write"
  fi
}

# [S-023-06] idle 允许绝对路径 step-manager enter
TOTAL=$((TOTAL + 1))
{
  box=$(new_box)
  trap 'rm -rf "$box"' EXIT
  node -e 'const fs=require("fs");const f=process.argv[1];const s=JSON.parse(fs.readFileSync(f,"utf-8"));s.current_phase="idle";fs.writeFileSync(f,JSON.stringify(s,null,2)+"\n","utf-8");' "$box/.step/state.json"
  cmd="bash $box/scripts/step-manager.sh enter --mode full --change init"
  out=$(cd "$box" && bash ./scripts/step-manager.sh assert-phase --tool Bash --command "$cmd" 2>&1)
  code=$?
  rm -rf "$box"
  trap - EXIT
  if [ "$code" -eq 0 ]; then
    pass_case "[S-023-06] idle 允许绝对路径 step-manager enter"
  else
    echo "    detail: $out"
    fail_case "[S-023-06] idle 允许绝对路径 step-manager enter"
  fi
}

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
