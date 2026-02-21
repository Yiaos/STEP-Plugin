#!/bin/bash
# T-006 测试：Lite Mode + 自主操作规则 + baseline 跟踪 + 语义化命名
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

echo "=== T-006: Lite Mode + 自主操作规则 + baseline 跟踪 + 语义化命名 ==="

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
  ! grep -q '自主操作规则' '$SCRIPT_DIR/AGENTS.md'
"

# ── Lite Mode ──

# [S-006-04] gate.sh 使用 quick/lite/full
assert "[S-006-04] gate.sh 使用 quick/lite/full" bash -c "
  grep -q 'lite' '$SCRIPT_DIR/scripts/gate.sh'
  grep -q 'full' '$SCRIPT_DIR/scripts/gate.sh'
  grep -q 'quick' '$SCRIPT_DIR/scripts/gate.sh'
  ! grep -q 'standard' '$SCRIPT_DIR/scripts/gate.sh'
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

# [S-006-06] lite-task.md 模板存在且包含 mode=lite
assert "[S-006-06] lite-task.md 模板包含 mode=lite" bash -c "
  [ -f '$SCRIPT_DIR/templates/lite-task.md' ]
  grep -q '\`\`\`json task' '$SCRIPT_DIR/templates/lite-task.md'
  grep -q 'mode' '$SCRIPT_DIR/templates/lite-task.md'
  grep -q 'lite' '$SCRIPT_DIR/templates/lite-task.md'
"

# [S-006-07] lite-task.md 模板使用语义化 slug
assert "[S-006-07] lite-task.md 使用语义化 slug (task-slug)" bash -c "
  grep -q 'task-slug' '$SCRIPT_DIR/templates/lite-task.md'
"

# [S-006-08] lite-task.md 使用 gate lite
assert "[S-006-08] lite-task.md 使用 gate lite" bash -c "
  grep -q 'gate.sh lite' '$SCRIPT_DIR/templates/lite-task.md'
"

# [S-006-09] lite-task.md 存放路径为 tasks/（非 lite/）
assert "[S-006-09] lite-task.md 注释指向 tasks/" bash -c "
  grep -q 'parent_baseline' '$SCRIPT_DIR/templates/lite-task.md'
  ! grep -q '/lite/' '$SCRIPT_DIR/templates/lite-task.md'
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
  grep -q 'gate.sh lite' '$SCRIPT_DIR/skills/step/SKILL.md'
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
  grep -q '^\- \[x\]' '$SCRIPT_DIR/.step/baseline.md'
"

# [S-006-17] WORKFLOW.md Step 6 包含 baseline 跟踪规则
assert "[S-006-17] WORKFLOW.md Step 6 包含 baseline 跟踪规则" bash -c "
  grep -q 'baseline.md.*标记.*\[x\]' '$SCRIPT_DIR/WORKFLOW.md' || grep -q 'baseline.md 对应.*\[x\]' '$SCRIPT_DIR/WORKFLOW.md'
"

# [S-006-18] SKILL.md 硬规则包含 Baseline 完成跟踪
assert "[S-006-18] SKILL.md 硬规则包含 Baseline 完成跟踪" bash -c "
  grep -q 'Baseline 完成跟踪' '$SCRIPT_DIR/skills/step/SKILL.md'
"

# ── 语义化命名 ──

# [S-006-19] task.md 模板使用语义化 slug
assert "[S-006-19] task.md 模板使用语义化 slug" bash -c "
  grep -q '\`\`\`json task' '$SCRIPT_DIR/templates/task.md'
  grep -q 'task-slug' '$SCRIPT_DIR/templates/task.md'
  grep -q 'S-task-slug-01' '$SCRIPT_DIR/templates/task.md'
  grep -q 'mode' '$SCRIPT_DIR/templates/task.md'
  grep -q 'full' '$SCRIPT_DIR/templates/task.md'
"

# [S-006-20] WORKFLOW.md 任务示例使用语义化 slug
assert "[S-006-20] WORKFLOW.md 示例用语义化 slug" bash -c "
  grep -q 'user-register-api' '$SCRIPT_DIR/WORKFLOW.md'
  grep -q 'S-user-register-api-01' '$SCRIPT_DIR/WORKFLOW.md'
  ! grep -q 'id: T-003' '$SCRIPT_DIR/WORKFLOW.md'
"

# [S-006-21] WORKFLOW.md 包含命名规则表
assert "[S-006-21] WORKFLOW.md 包含命名规则表" bash -c "
  grep -q '命名规则' '$SCRIPT_DIR/WORKFLOW.md'
  grep -q 'kebab-case' '$SCRIPT_DIR/WORKFLOW.md'
"

# [S-006-22] SKILL.md 包含命名规则
assert "[S-006-22] SKILL.md 包含命名规则" bash -c "
  grep -q '命名规则' '$SCRIPT_DIR/skills/step/SKILL.md'
  grep -q 'slug' '$SCRIPT_DIR/skills/step/SKILL.md'
"

# [S-006-23] README.md 使用语义化 slug 示例
assert "[S-006-23] README.md 使用语义化 slug" bash -c "
  grep -q 'user-register-api' '$SCRIPT_DIR/README.md'
  grep -q 'fix-empty-password' '$SCRIPT_DIR/README.md'
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
