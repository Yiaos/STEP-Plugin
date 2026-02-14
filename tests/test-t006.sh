#!/bin/bash
# T-006 测试：Lite Mode + 自主操作规则 + baseline 跟踪
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
PASS=0; FAIL=0; TOTAL=0

assert() {
  TOTAL=$((TOTAL + 1))
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "  ✅ $name"; PASS=$((PASS + 1))
  else
    echo "  ❌ $name"; FAIL=$((FAIL + 1))
  fi
}

echo "=== T-006: Lite Mode + 自主操作规则 + baseline 跟踪 ==="

# ── 自主操作规则 ──

# [S-006-01] WORKFLOW.md 包含自主操作规则
assert "[S-006-01] WORKFLOW.md 包含自主操作规则" bash -c "
  grep -q '自主操作规则' '$SCRIPT_DIR/WORKFLOW.md'
  grep -q '不需要用户确认' '$SCRIPT_DIR/WORKFLOW.md'
  grep -q '需要用户确认' '$SCRIPT_DIR/WORKFLOW.md'
"

# [S-006-02] SKILL.md 包含自主操作规则精简版
assert "[S-006-02] SKILL.md 包含自主操作规则精简版" bash -c "
  grep -q '自主操作规则' '$SCRIPT_DIR/skills/step/SKILL.md'
  grep -q '不需要确认' '$SCRIPT_DIR/skills/step/SKILL.md'
  grep -q '需要确认' '$SCRIPT_DIR/skills/step/SKILL.md'
"

# [S-006-03] AGENTS.md 不包含自主操作规则（已还原）
assert "[S-006-03] AGENTS.md 不包含自主操作规则" bash -c "
  ! grep -q '自主操作规则' '/Users/iaos/worksp/dev/agent/AGENTS.md'
"

# ── Lite Mode ──

# [S-006-04] gate.sh 支持 lite 级别
assert "[S-006-04] gate.sh 支持 lite 级别" bash -c "
  grep -q 'lite' '$SCRIPT_DIR/scripts/gate.sh'
"

# [S-006-05] gate.sh lite 级别跳过 build（不含 build 在 lite 分支）
assert "[S-006-05] gate.sh lite 跳过 build" bash -c "
  # lite 级别应运行 lint+typecheck+test 但不运行 build
  # 只有 full 级别才运行 build
  grep -q 'LEVEL.*=.*full' '$SCRIPT_DIR/scripts/gate.sh'
  grep -q 'lite.*skip' '$SCRIPT_DIR/scripts/gate.sh' || grep -q 'full.*build' '$SCRIPT_DIR/scripts/gate.sh'
"

# [S-006-06] step-init.sh 创建 lite 和 archive 目录
assert "[S-006-06] step-init.sh 创建 lite 和 archive 目录" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  bash '$SCRIPT_DIR/scripts/step-init.sh' >/dev/null 2>&1
  [ -d .step/lite ]
  [ -d .step/archive ]
"

# [S-006-07] lite-task.yaml 模板存在且包含 mode: lite
assert "[S-006-07] lite-task.yaml 模板包含 mode: lite" bash -c "
  [ -f '$SCRIPT_DIR/templates/lite-task.yaml' ]
  grep -q 'mode: lite' '$SCRIPT_DIR/templates/lite-task.yaml'
"

# [S-006-08] lite-task.yaml 模板场景 ID 用 L 前缀
assert "[S-006-08] lite-task.yaml 场景 ID 用 L 前缀" bash -c "
  grep -q 'S-L' '$SCRIPT_DIR/templates/lite-task.yaml'
"

# [S-006-09] WORKFLOW.md 包含 Lite Mode 完整规范
assert "[S-006-09] WORKFLOW.md 包含 Lite Mode 完整规范" bash -c "
  grep -q 'Lite Mode' '$SCRIPT_DIR/WORKFLOW.md'
  grep -q 'L1 Quick Spec' '$SCRIPT_DIR/WORKFLOW.md'
  grep -q 'L2 Execution' '$SCRIPT_DIR/WORKFLOW.md'
  grep -q 'L3 Quick Review' '$SCRIPT_DIR/WORKFLOW.md'
"

# [S-006-10] SKILL.md 包含 Lite Mode 精简规则
assert "[S-006-10] SKILL.md 包含 Lite Mode 精简规则" bash -c "
  grep -q 'Lite Mode' '$SCRIPT_DIR/skills/step/SKILL.md'
  grep -q 'gate.sh lite' '$SCRIPT_DIR/skills/step/SKILL.md' || grep -q 'gate lite' '$SCRIPT_DIR/skills/step/SKILL.md'
"

# [S-006-11] README.md 包含 Lite Mode 文档
assert "[S-006-11] README.md 包含 Lite Mode 文档" bash -c "
  grep -q 'Lite Mode' '$SCRIPT_DIR/README.md'
  grep -q '.step/lite/' '$SCRIPT_DIR/README.md' || grep -q 'lite/' '$SCRIPT_DIR/README.md'
  grep -q '.step/archive/' '$SCRIPT_DIR/README.md' || grep -q 'archive/' '$SCRIPT_DIR/README.md'
"

# ── Baseline 完成跟踪 ──

# [S-006-12] baseline.md 已完成项标记为 [x]
assert "[S-006-12] baseline.md 已完成项标记为 [x]" bash -c "
  set -e
  # 所有 F-x 项都应该标记为 [x]
  ! grep -q '^\- \[ \] F-' '$SCRIPT_DIR/.step/baseline.md'
  grep -q '^\- \[x\] F-1' '$SCRIPT_DIR/.step/baseline.md'
  grep -q '^\- \[x\] F-8' '$SCRIPT_DIR/.step/baseline.md'
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
