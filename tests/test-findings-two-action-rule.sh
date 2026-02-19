#!/bin/bash
# T-025 测试：findings 2-action rule
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

echo "=== T-025: findings 2-action rule ==="

assert "[S-findings-two-action-rule-01] SKILL.md 包含 findings 2-action rule" bash -c "
  grep -q 'Findings 2-Action Rule' '$SCRIPT_DIR/skills/step/SKILL.md'
"

assert "[S-findings-two-action-rule-02] WORKFLOW.md 包含 2-Action Rule 说明" bash -c "
  grep -q '2-Action Rule' '$SCRIPT_DIR/WORKFLOW.md'
"

assert "[S-findings-two-action-rule-03] findings 模板包含 checkpoint 文案" bash -c "
  grep -q '2-action checkpoint' '$SCRIPT_DIR/templates/findings.md'
"

assert "[S-findings-two-action-rule-04] gate.test 纳入本测试" bash -c "
  grep -q 'test-findings-two-action-rule.sh' '$SCRIPT_DIR/.step/config.json'
"

assert "[S-findings-two-action-rule-05] WORKFLOW 约束 next_action != failed_action" bash -c "
  grep -q 'next_action.*failed_action.*不同' '$SCRIPT_DIR/WORKFLOW.md'
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
