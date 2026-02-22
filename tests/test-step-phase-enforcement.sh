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

assert() {
  local _name="$1"; shift
  "$@"
}

new_box() {
  local dir
  dir=$(mktemp -d)
  mkdir -p "$dir/.step" "$dir/scripts"
  cp "$SCRIPT_DIR/templates/state.json" "$dir/.step/state.json"
  cp "$SCRIPT_DIR/scripts/step-manager.sh" "$dir/scripts/step-manager.sh"
  cp "$SCRIPT_DIR/scripts/step-core.js" "$dir/scripts/step-core.js"
  chmod +x "$dir/scripts/step-manager.sh" "$dir/scripts/step-core.js"
  printf '%s' "$dir"
}

echo "=== T-023: STEP phase enforcement ==="

# [S-stabilize-step-trigger-enforcement-01] idle 阶段阻断 Write
TOTAL=$((TOTAL + 1))
{
  box=$(new_box)
  trap 'rm -rf "$box"' EXIT
  node -e 'const fs=require("fs");const f=process.argv[1];const s=JSON.parse(fs.readFileSync(f,"utf-8"));s.current_phase="idle";fs.writeFileSync(f,JSON.stringify(s,null,2)+"\n","utf-8");' "$box/.step/state.json"
  out=$(cd "$box" && bash "$box/scripts/step-manager.sh" assert-phase --tool Write 2>&1)
  code=$?
  rm -rf "$box"
  trap - EXIT
  if [ "$code" -ne 0 ] && printf '%s' "$out" | grep -q '不允许工具=Write'; then
    pass_case "[S-stabilize-step-trigger-enforcement-01] idle 阶段阻断 Write"
  else
    fail_case "[S-stabilize-step-trigger-enforcement-01] idle 阶段阻断 Write"
  fi
}

# [S-stabilize-step-trigger-enforcement-02] full 模式 phase-1 启用写锁阻断 Write
TOTAL=$((TOTAL + 1))
{
  box=$(new_box)
  trap 'rm -rf "$box"' EXIT
  (cd "$box" && bash "$box/scripts/step-manager.sh" enter --mode full --change init >/dev/null 2>&1)
  (cd "$box" && bash "$box/scripts/step-manager.sh" transition --to phase-1-prd >/dev/null 2>&1)
  out=$(cd "$box" && bash "$box/scripts/step-manager.sh" assert-phase --tool Write 2>&1)
  code=$?
  rm -rf "$box"
  trap - EXIT
  if [ "$code" -ne 0 ] && printf '%s' "$out" | grep -q '已启用写锁'; then
    pass_case "[S-stabilize-step-trigger-enforcement-02] full 模式 phase-1 启用写锁阻断 Write"
  else
    fail_case "[S-stabilize-step-trigger-enforcement-02] full 模式 phase-1 启用写锁阻断 Write"
  fi
}

# [S-stabilize-step-trigger-enforcement-03] 非法 phase 跳转被拒绝
TOTAL=$((TOTAL + 1))
{
  box=$(new_box)
  trap 'rm -rf "$box"' EXIT
  (cd "$box" && bash "$box/scripts/step-manager.sh" enter --mode full --change init >/dev/null 2>&1)
  out=$(cd "$box" && bash "$box/scripts/step-manager.sh" transition --to phase-4-execution 2>&1)
  code=$?
  rm -rf "$box"
  trap - EXIT
  if [ "$code" -ne 0 ] && printf '%s' "$out" | grep -q '非法 phase 迁移'; then
    pass_case "[S-stabilize-step-trigger-enforcement-03] 非法 phase 跳转被拒绝"
  else
    fail_case "[S-stabilize-step-trigger-enforcement-03] 非法 phase 跳转被拒绝"
  fi
}

# [S-stabilize-step-trigger-enforcement-04] 禁止 step-core 直接写 current_phase
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
    pass_case "[S-stabilize-step-trigger-enforcement-04] 禁止 step-core 直接写 current_phase"
  else
    fail_case "[S-stabilize-step-trigger-enforcement-04] 禁止 step-core 直接写 current_phase"
  fi
}

# [S-stabilize-step-trigger-enforcement-05] pretool guard 在 idle 阻断 Write
TOTAL=$((TOTAL + 1))
{
  box=$(mktemp -d)
  trap 'rm -rf "$box"' EXIT
  mkdir -p "$box/.step" "$box/scripts"
  cp "$SCRIPT_DIR/templates/state.json" "$box/.step/state.json"
  cp "$SCRIPT_DIR/scripts/step-manager.sh" "$box/scripts/step-manager.sh"
  cp "$SCRIPT_DIR/scripts/step-core.js" "$box/scripts/step-core.js"
  cp "$SCRIPT_DIR/scripts/step-pretool-guard.sh" "$box/scripts/step-pretool-guard.sh"
  chmod +x "$box/scripts/step-manager.sh" "$box/scripts/step-core.js" "$box/scripts/step-pretool-guard.sh"
  node -e 'const fs=require("fs");const f=process.argv[1];const s=JSON.parse(fs.readFileSync(f,"utf-8"));s.current_phase="idle";fs.writeFileSync(f,JSON.stringify(s,null,2)+"\n","utf-8");' "$box/.step/state.json"
  out=$(cd "$box" && OPENCODE_TOOL_NAME=Write bash "$box/scripts/step-pretool-guard.sh" 2>&1)
  code=$?
  assert "[S-stabilize-step-trigger-enforcement-05] pretool guard 在 idle 阻断 Write" bash -c "[ '$code' -ne 0 ] && printf '%s' \"$out\" | grep -q '不允许工具=Write'"
  rm -rf "$box"
  trap - EXIT
  if [ "$code" -ne 0 ] && printf '%s' "$out" | grep -q '不允许工具=Write'; then
    pass_case "[S-stabilize-step-trigger-enforcement-05] pretool guard 在 idle 阻断 Write"
  else
    fail_case "[S-stabilize-step-trigger-enforcement-05] pretool guard 在 idle 阻断 Write"
  fi
}

# [S-stabilize-step-trigger-enforcement-06] idle 允许绝对路径 step-manager enter
TOTAL=$((TOTAL + 1))
{
  box=$(new_box)
  trap 'rm -rf "$box"' EXIT
  node -e 'const fs=require("fs");const f=process.argv[1];const s=JSON.parse(fs.readFileSync(f,"utf-8"));s.current_phase="idle";fs.writeFileSync(f,JSON.stringify(s,null,2)+"\n","utf-8");' "$box/.step/state.json"
  cmd="bash $box/scripts/step-manager.sh enter --mode full --change init"
  out=$(cd "$box" && bash "$box/scripts/step-manager.sh" assert-phase --tool Bash --command "$cmd" 2>&1)
  code=$?
  assert "[S-stabilize-step-trigger-enforcement-06] idle 允许绝对路径 step-manager enter" test "$code" -eq 0
  rm -rf "$box"
  trap - EXIT
  if [ "$code" -eq 0 ]; then
    pass_case "[S-stabilize-step-trigger-enforcement-06] idle 允许绝对路径 step-manager enter"
  else
    echo "    detail: $out"
    fail_case "[S-stabilize-step-trigger-enforcement-06] idle 允许绝对路径 step-manager enter"
  fi
}

# [S-stabilize-step-trigger-enforcement-07] phase-1 阻断实现类 Bash（npm test）
TOTAL=$((TOTAL + 1))
{
  box=$(new_box)
  trap 'rm -rf "$box"' EXIT
  (cd "$box" && bash "$box/scripts/step-manager.sh" enter --mode full --change init >/dev/null 2>&1)
  (cd "$box" && bash "$box/scripts/step-manager.sh" transition --to phase-1-prd >/dev/null 2>&1)
  out=$(cd "$box" && bash "$box/scripts/step-manager.sh" assert-phase --tool Bash --command "npm test" 2>&1)
  code=$?
  assert "[S-stabilize-step-trigger-enforcement-07] phase-1 阻断实现类 Bash（npm test）" bash -c "[ '$code' -ne 0 ] && printf '%s' \"$out\" | grep -q '仅允许流程控制或只读命令'"
  rm -rf "$box"
  trap - EXIT
  if [ "$code" -ne 0 ] && printf '%s' "$out" | grep -q '仅允许流程控制或只读命令'; then
    pass_case "[S-stabilize-step-trigger-enforcement-07] phase-1 阻断实现类 Bash（npm test）"
  else
    fail_case "[S-stabilize-step-trigger-enforcement-07] phase-1 阻断实现类 Bash（npm test）"
  fi
}

# [S-stabilize-step-trigger-enforcement-08] pretool guard 可自动 enter（idle -> phase-0）
TOTAL=$((TOTAL + 1))
{
  box=$(mktemp -d)
  trap 'rm -rf "$box"' EXIT
  mkdir -p "$box/.step" "$box/scripts"
  cp "$SCRIPT_DIR/templates/state.json" "$box/.step/state.json"
  cp "$SCRIPT_DIR/scripts/step-manager.sh" "$box/scripts/step-manager.sh"
  cp "$SCRIPT_DIR/scripts/step-core.js" "$box/scripts/step-core.js"
  cp "$SCRIPT_DIR/scripts/step-pretool-guard.sh" "$box/scripts/step-pretool-guard.sh"
  chmod +x "$box/scripts/step-manager.sh" "$box/scripts/step-core.js" "$box/scripts/step-pretool-guard.sh"
  node -e 'const fs=require("fs");const f=process.argv[1];const s=JSON.parse(fs.readFileSync(f,"utf-8"));s.current_phase="idle";fs.writeFileSync(f,JSON.stringify(s,null,2)+"\n","utf-8");' "$box/.step/state.json"
  out=$(cd "$box" && STEP_AUTO_ENTER=true STEP_AUTO_ENTER_MODE=full OPENCODE_TOOL_NAME=Write bash "$box/scripts/step-pretool-guard.sh" 2>&1)
  code=$?
  phase=$(node -e 'const fs=require("fs");const s=JSON.parse(fs.readFileSync(process.argv[1],"utf-8"));process.stdout.write(s.current_phase||"")' "$box/.step/state.json")
  assert "[S-stabilize-step-trigger-enforcement-08] pretool guard 可自动 enter（idle -> phase-0）" bash -c "[ '$code' -ne 0 ] && [ '$phase' = 'phase-0-discovery' ]"
  rm -rf "$box"
  trap - EXIT
  if [ "$code" -ne 0 ] && [ "$phase" = "phase-0-discovery" ] && printf '%s' "$out" | grep -q '不允许工具=Write'; then
    pass_case "[S-stabilize-step-trigger-enforcement-08] pretool guard 可自动 enter（idle -> phase-0）"
  else
    fail_case "[S-stabilize-step-trigger-enforcement-08] pretool guard 可自动 enter（idle -> phase-0）"
  fi
}

# [S-stabilize-step-trigger-enforcement-09] lite 模式 phase-1 不启用写锁
TOTAL=$((TOTAL + 1))
{
  box=$(new_box)
  trap 'rm -rf "$box"' EXIT
  (cd "$box" && bash "$box/scripts/step-manager.sh" enter --mode lite --change init >/dev/null 2>&1)
  out=$(cd "$box" && bash "$box/scripts/step-manager.sh" assert-phase --tool Write 2>&1)
  code=$?
  assert "[S-stabilize-step-trigger-enforcement-09] lite 模式 phase-1 不启用写锁" test "$code" -eq 0
  rm -rf "$box"
  trap - EXIT
  if [ "$code" -eq 0 ]; then
    pass_case "[S-stabilize-step-trigger-enforcement-09] lite 模式 phase-1 不启用写锁"
  else
    echo "    detail: $out"
    fail_case "[S-stabilize-step-trigger-enforcement-09] lite 模式 phase-1 不启用写锁"
  fi
}

# [S-stabilize-step-trigger-enforcement-10] full 模式 phase-1 必须委派 step-pm
TOTAL=$((TOTAL + 1))
{
  box=$(new_box)
  trap 'rm -rf "$box"' EXIT
  cp "$SCRIPT_DIR/templates/config.json" "$box/.step/config.json"
  (cd "$box" && bash "$box/scripts/step-manager.sh" enter --mode full --change init >/dev/null 2>&1)
  (cd "$box" && bash "$box/scripts/step-manager.sh" transition --to phase-1-prd >/dev/null 2>&1)
  out=$(cd "$box" && bash "$box/scripts/step-manager.sh" assert-dispatch --tool Task --agent step-architect 2>&1)
  code=$?
  assert "[S-stabilize-step-trigger-enforcement-10] full 模式 phase-1 必须委派 step-pm" bash -c "[ '$code' -ne 0 ] && printf '%s' \"$out\" | grep -q '必须委派给 step-pm'"
  rm -rf "$box"
  trap - EXIT
  if [ "$code" -ne 0 ] && printf '%s' "$out" | grep -q '必须委派给 step-pm'; then
    pass_case "[S-stabilize-step-trigger-enforcement-10] full 模式 phase-1 必须委派 step-pm"
  else
    fail_case "[S-stabilize-step-trigger-enforcement-10] full 模式 phase-1 必须委派 step-pm"
  fi
}

# [S-stabilize-step-trigger-enforcement-11] lite 模式不强制委派 step-pm
TOTAL=$((TOTAL + 1))
{
  box=$(new_box)
  trap 'rm -rf "$box"' EXIT
  cp "$SCRIPT_DIR/templates/config.json" "$box/.step/config.json"
  (cd "$box" && bash "$box/scripts/step-manager.sh" enter --mode lite --change init >/dev/null 2>&1)
  out=$(cd "$box" && bash "$box/scripts/step-manager.sh" assert-dispatch --tool Task --agent step-architect 2>&1)
  code=$?
  assert "[S-stabilize-step-trigger-enforcement-11] lite 模式不强制委派 step-pm" test "$code" -eq 0
  rm -rf "$box"
  trap - EXIT
  if [ "$code" -eq 0 ]; then
    pass_case "[S-stabilize-step-trigger-enforcement-11] lite 模式不强制委派 step-pm"
  else
    echo "    detail: $out"
    fail_case "[S-stabilize-step-trigger-enforcement-11] lite 模式不强制委派 step-pm"
  fi
}

# [S-manager-core-migrate-01] manager enter sets phase and change
TOTAL=$((TOTAL + 1))
{
  box=$(new_box)
  trap 'rm -rf "$box"' EXIT
  (cd "$box" && bash "$box/scripts/step-manager.sh" enter --mode full --change test-change >/dev/null 2>&1)
  phase=$(node -e 'const fs=require("fs");const s=JSON.parse(fs.readFileSync(process.argv[1],"utf-8"));process.stdout.write(s.current_phase||"")' "$box/.step/state.json")
  change=$(node -e 'const fs=require("fs");const s=JSON.parse(fs.readFileSync(process.argv[1],"utf-8"));process.stdout.write(s.current_change||"")' "$box/.step/state.json")
  rm -rf "$box"
  trap - EXIT
  if [ "$phase" = "phase-0-discovery" ] && [ "$change" = "test-change" ]; then
    pass_case "[S-manager-core-migrate-01] manager enter sets phase and change"
  else
    fail_case "[S-manager-core-migrate-01] manager enter sets phase and change"
  fi
}

# [S-manager-core-migrate-02] manager transition updates phase
TOTAL=$((TOTAL + 1))
{
  box=$(new_box)
  trap 'rm -rf "$box"' EXIT
  (cd "$box" && bash "$box/scripts/step-manager.sh" enter --mode full --change init >/dev/null 2>&1)
  (cd "$box" && bash "$box/scripts/step-manager.sh" transition --to phase-1-prd >/dev/null 2>&1)
  phase=$(node -e 'const fs=require("fs");const s=JSON.parse(fs.readFileSync(process.argv[1],"utf-8"));process.stdout.write(s.current_phase||"")' "$box/.step/state.json")
  rm -rf "$box"
  trap - EXIT
  if [ "$phase" = "phase-1-prd" ]; then
    pass_case "[S-manager-core-migrate-02] manager transition updates phase"
  else
    fail_case "[S-manager-core-migrate-02] manager transition updates phase"
  fi
}

# [S-manager-core-migrate-03] invalid transition rejected
TOTAL=$((TOTAL + 1))
{
  box=$(new_box)
  trap 'rm -rf "$box"' EXIT
  (cd "$box" && bash "$box/scripts/step-manager.sh" enter --mode full --change init >/dev/null 2>&1)
  out=$(cd "$box" && bash "$box/scripts/step-manager.sh" transition --to phase-4-execution 2>&1)
  code=$?
  rm -rf "$box"
  trap - EXIT
  if [ "$code" -ne 0 ] && printf '%s' "$out" | grep -q '非法 phase 迁移'; then
    pass_case "[S-manager-core-migrate-03] invalid transition rejected"
  else
    fail_case "[S-manager-core-migrate-03] invalid transition rejected"
  fi
}

# [S-manager-core-migrate-04] thin shell delegates correctly
TOTAL=$((TOTAL + 1))
{
  if grep -q 'node "$CORE_SCRIPT" manager' "$SCRIPT_DIR/scripts/step-manager.sh"; then
    pass_case "[S-manager-core-migrate-04] thin shell delegates correctly"
  else
    fail_case "[S-manager-core-migrate-04] thin shell delegates correctly"
  fi
}

# [S-manager-core-migrate-05] missing state handled gracefully
TOTAL=$((TOTAL + 1))
{
  box=$(mktemp -d)
  trap 'rm -rf "$box"' EXIT
  mkdir -p "$box/scripts"
  cp "$SCRIPT_DIR/scripts/step-manager.sh" "$box/scripts/step-manager.sh"
  cp "$SCRIPT_DIR/scripts/step-core.js" "$box/scripts/step-core.js"
  chmod +x "$box/scripts/step-manager.sh" "$box/scripts/step-core.js"
  out=$(cd "$box" && bash "$box/scripts/step-manager.sh" status-line 2>&1)
  code=$?
  rm -rf "$box"
  trap - EXIT
  if [ "$code" -eq 0 ] && printf '%s' "$out" | grep -q 'Phase idle'; then
    pass_case "[S-manager-core-migrate-05] missing state handled gracefully"
  else
    fail_case "[S-manager-core-migrate-05] missing state handled gracefully"
  fi
}

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
