#!/bin/bash
# T-036 测试：review/commit/archive 文档顺序一致性

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

echo "=== T-036: doc flow consistency ==="

assert "[S-doc-flow-01] WORKFLOW uses review->commit->archive(optional)" bash -c "
  set -e
  grep -q 'execution -> review -> commit -> archive(optional)' '$SCRIPT_DIR/WORKFLOW.md'
"

assert "[S-doc-flow-02] command docs avoid archive-before-commit" bash -c "
  set -e
  grep -q 'review + commit/push（完成后可归档）' '$SCRIPT_DIR/commands/step.md'
  ! grep -qi 'review.*archive.*commit' '$SCRIPT_DIR/commands/step.md'
"

assert "[S-doc-flow-03] SKILL uses commit then archive question" bash -c "
  set -e
  grep -q 'Commit/Push → 询问是否归档' '$SCRIPT_DIR/skills/step/SKILL.md'
"

assert "[S-doc-flow-04] README sequence updated" bash -c "
  set -e
  grep -q 'Commit/Push → 询问归档' '$SCRIPT_DIR/README.md'
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
