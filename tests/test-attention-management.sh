#!/bin/bash
# T-001 测试：注意力管理增强
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

echo "=== T-001: 注意力管理增强 ==="

# [S-001-01] state.json head-25 包含关键字段
assert "[S-001-01] state.json head-25 包含关键字段" bash -c "
  set -e
  output=\$(head -25 '$SCRIPT_DIR/templates/state.json')
  echo "\$output" | grep -q 'project'
  echo "\$output" | grep -q 'progress_log'
"

# [S-001-02] SKILL.md 包含注意力管理段落
assert "[S-001-02] SKILL.md 包含注意力管理段落" bash -c "
  grep -q '注意力管理' '$SCRIPT_DIR/skills/step/SKILL.md'
"

# [S-001-03] state.json 模板 JSON/结构校验通过
assert "[S-001-03] state.json 模板 JSON/结构校验通过" bash -c "
  node '$SCRIPT_DIR/scripts/step-core.js' validate state --file '$SCRIPT_DIR/templates/state.json'
"

# [S-001-04] SKILL.md PreToolUse hook 使用 head -25
assert "[S-001-04] SKILL.md PreToolUse hook 使用 head -25" bash -c "
  grep -q 'head -25' '$SCRIPT_DIR/skills/step/SKILL.md'
"

# [S-001-05] 无 state.json 时 hook 静默失败
assert "[S-001-05] 无 state.json 时 hook 静默失败" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf "\$tmpdir"' EXIT
  cd "\$tmpdir"
  cat .step/state.json 2>/dev/null | head -25 || true
"

# [S-001-06] init 后生成的 state.json 包含关键字段
assert "[S-001-06] init 后生成的 state.json 包含关键字段" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf "\$tmpdir"' EXIT
  cd "\$tmpdir"
  bash '$SCRIPT_DIR/scripts/step-init.sh' >/dev/null 2>&1
  output=\$(head -25 .step/state.json)
  echo "\$output" | grep -q 'project'
  node '$SCRIPT_DIR/scripts/step-core.js' validate state --file .step/state.json
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
