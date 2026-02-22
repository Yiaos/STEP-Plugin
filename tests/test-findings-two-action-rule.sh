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

assert "[S-optimize-2ar-01] SKILL 包含分级阈值规则" bash -c "
  grep -q 'Discovery/Lite-L1 每 2' '$SCRIPT_DIR/skills/step/SKILL.md'
  grep -q 'Execution/Review 阶段每 4' '$SCRIPT_DIR/skills/step/SKILL.md'
"

assert "[S-optimize-2ar-02] stop-check 包含 phase 阈值检查" bash -c "
  grep -q 'Findings.*阈值' '$SCRIPT_DIR/scripts/step-stop-check.sh' || grep -q 'findings 更新频率检查' '$SCRIPT_DIR/scripts/step-stop-check.sh'
"

assert "[S-optimize-2ar-03] phase-4 uses threshold 4" bash -c "
  grep -q 'phase-4-execution\|phase-5-review\|lite-l2-execution\|lite-l3-review' '$SCRIPT_DIR/scripts/step-stop-check.sh'
  grep -q 'FINDINGS_THRESHOLD=4' '$SCRIPT_DIR/scripts/step-stop-check.sh'
"

assert "[S-optimize-2ar-04] planning phases use threshold 3" bash -c "
  grep -q 'phase-1-prd\|phase-2-tech-design\|phase-3-planning' '$SCRIPT_DIR/scripts/step-stop-check.sh'
  grep -q 'FINDINGS_THRESHOLD=3' '$SCRIPT_DIR/scripts/step-stop-check.sh'
"

assert "[S-optimize-2ar-05] unknown phase falls back to threshold 2" bash -c "
  grep -q '\*)' '$SCRIPT_DIR/scripts/step-stop-check.sh'
  grep -q 'FINDINGS_THRESHOLD=2' '$SCRIPT_DIR/scripts/step-stop-check.sh'
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
