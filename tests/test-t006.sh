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

# [S-006-04] gate.sh 无 lite 级别（Lite Mode 使用 standard gate）
assert "[S-006-04] gate.sh 只有 quick/standard/full 三级" bash -c "
  grep -q 'quick' '$SCRIPT_DIR/scripts/gate.sh'
  grep -q 'standard' '$SCRIPT_DIR/scripts/gate.sh'
  grep -q 'full' '$SCRIPT_DIR/scripts/gate.sh'
  # gate.sh 注释中不应有 lite 级别
  ! grep -q '^\#.*lite' '$SCRIPT_DIR/scripts/gate.sh'
"

# [S-006-05] step-init.sh 创建 archive 目录（无 lite 目录）
assert "[S-006-05] step-init.sh 创建 archive 但不创建 lite 目录" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  bash '$SCRIPT_DIR/scripts/step-init.sh' >/dev/null 2>&1
  [ -d .step/archive ]
  [ ! -d .step/lite ]
"

# [S-006-06] lite-task.yaml 模板存在且包含 mode: lite
assert "[S-006-06] lite-task.yaml 模板包含 mode: lite" bash -c "
  [ -f '$SCRIPT_DIR/templates/lite-task.yaml' ]
  grep -q 'mode: lite' '$SCRIPT_DIR/templates/lite-task.yaml'
"

# [S-006-07] lite-task.yaml 模板场景 ID 用 L 前缀
assert "[S-006-07] lite-task.yaml 场景 ID 用 L 前缀" bash -c "
  grep -q 'S-L' '$SCRIPT_DIR/templates/lite-task.yaml'
"

# [S-006-08] lite-task.yaml 使用 gate standard（非 lite）
assert "[S-006-08] lite-task.yaml 使用 gate standard" bash -c "
  grep -q 'gate.sh standard' '$SCRIPT_DIR/templates/lite-task.yaml'
"

# [S-006-09] lite-task.yaml 存放路径为 tasks/（非 lite/）
assert "[S-006-09] lite-task.yaml 注释指向 tasks/" bash -c "
  grep -q 'tasks/' '$SCRIPT_DIR/templates/lite-task.yaml'
"

# [S-006-10] WORKFLOW.md 包含 Lite Mode 完整规范
assert "[S-006-10] WORKFLOW.md 包含 Lite Mode 完整规范" bash -c "
  grep -q 'Lite Mode' '$SCRIPT_DIR/WORKFLOW.md'
  grep -q 'L1 Quick Spec' '$SCRIPT_DIR/WORKFLOW.md'
  grep -q 'L2 Execution' '$SCRIPT_DIR/WORKFLOW.md'
  grep -q 'L3.*Review' '$SCRIPT_DIR/WORKFLOW.md'
"

# [S-006-11] WORKFLOW.md L3 包含完整 Code Review
assert "[S-006-11] WORKFLOW.md L3 包含完整 Code Review" bash -c "
  grep -q '完整 Code Review' '$SCRIPT_DIR/WORKFLOW.md' || grep -q 'Code Review（按 Phase 5 规则）' '$SCRIPT_DIR/WORKFLOW.md'
"

# [S-006-12] WORKFLOW.md 包含批量任务处理
assert "[S-006-12] WORKFLOW.md 包含批量任务处理" bash -c "
  grep -q 'Lite Batch' '$SCRIPT_DIR/WORKFLOW.md' || grep -q '批量' '$SCRIPT_DIR/WORKFLOW.md'
"

# [S-006-13] SKILL.md 包含 Lite Mode 精简规则
assert "[S-006-13] SKILL.md 包含 Lite Mode 精简规则" bash -c "
  grep -q 'Lite Mode' '$SCRIPT_DIR/skills/step/SKILL.md'
  grep -q 'gate.sh standard' '$SCRIPT_DIR/skills/step/SKILL.md'
"

# [S-006-14] SKILL.md L3 Review 与 Full Mode 相同
assert "[S-006-14] SKILL.md Lite L3 完整 Code Review" bash -c "
  grep -q '完整 Code Review' '$SCRIPT_DIR/skills/step/SKILL.md'
"

# [S-006-15] README.md 包含 Lite Mode 文档
assert "[S-006-15] README.md 包含 Lite Mode 文档" bash -c "
  grep -q 'Lite Mode' '$SCRIPT_DIR/README.md'
  grep -q 'archive/' '$SCRIPT_DIR/README.md'
"

# ── Baseline 完成跟踪 ──

# [S-006-16] baseline.md 已完成项标记为 [x]
assert "[S-006-16] baseline.md 已完成项标记为 [x]" bash -c "
  set -e
  ! grep -q '^\- \[ \] F-' '$SCRIPT_DIR/.step/baseline.md'
  grep -q '^\- \[x\] F-1' '$SCRIPT_DIR/.step/baseline.md'
  grep -q '^\- \[x\] F-8' '$SCRIPT_DIR/.step/baseline.md'
"

# [S-006-17] WORKFLOW.md Step 6 包含 baseline 跟踪规则
assert "[S-006-17] WORKFLOW.md Step 6 包含 baseline 跟踪规则" bash -c "
  grep -q 'baseline.md.*标记.*\[x\]' '$SCRIPT_DIR/WORKFLOW.md' || grep -q 'baseline.md 对应.*\[x\]' '$SCRIPT_DIR/WORKFLOW.md'
"

# [S-006-18] SKILL.md 硬规则包含 Baseline 完成跟踪
assert "[S-006-18] SKILL.md 硬规则包含 Baseline 完成跟踪" bash -c "
  grep -q 'Baseline 完成跟踪' '$SCRIPT_DIR/skills/step/SKILL.md'
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
