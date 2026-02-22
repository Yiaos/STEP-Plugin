#!/bin/bash
# T-027 测试：e2e 规则一致性

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

echo "=== T-027: e2e rule consistency ==="

assert "[S-unify-e2e-rule-01] SKILL 与 WORKFLOW 使用一致规则" bash -c "
  grep -q 'e2e 在 Full 模式必须，Lite 模式按需' '$SCRIPT_DIR/skills/step/SKILL.md'
  grep -q 'e2e 在 Full 模式必须，Lite 模式按需' '$SCRIPT_DIR/WORKFLOW.md'
"

assert "[S-unify-e2e-rule-02] 删除过时强制语句" bash -c "
  ! grep -q '所有测试类型必须.*unit / integration / e2e 都是必须' '$SCRIPT_DIR/skills/step/SKILL.md'
  ! grep -q '三种测试类型都是必须' '$SCRIPT_DIR/WORKFLOW.md'
"

assert "[S-unify-e2e-rule-03] inconsistency detected by test" bash -c "
  grep -q '! grep -q' '$SCRIPT_DIR/tests/test-e2e-rule-consistency.sh'
  grep -q '三种测试类型都是必须' '$SCRIPT_DIR/tests/test-e2e-rule-consistency.sh'
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
