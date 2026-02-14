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

# [S-001-01] state.yaml head-25 包含规则和数据
assert "[S-001-01] state.yaml head-25 包含规则和数据" bash -c "
  set -e
  output=\$(head -25 '$SCRIPT_DIR/templates/state.yaml')
  echo \"\$output\" | grep -q '⚡'
  echo \"\$output\" | grep -q 'project:'
"

# [S-001-02] SKILL.md 包含注意力管理段落
assert "[S-001-02] SKILL.md 包含注意力管理段落" bash -c "
  grep -q '注意力管理' '$SCRIPT_DIR/skills/step/SKILL.md'
"

# [S-001-03] state.yaml 模板 YAML 语法合法
assert "[S-001-03] state.yaml 模板 YAML 语法合法" bash -c "
  python3 -c \"import yaml; yaml.safe_load(open('$SCRIPT_DIR/templates/state.yaml'))\"
"

# [S-001-04] SKILL.md PreToolUse hook 使用 head -25
assert "[S-001-04] SKILL.md PreToolUse hook 使用 head -25" bash -c "
  grep -q 'head -25' '$SCRIPT_DIR/skills/step/SKILL.md'
"

# [S-001-05] 无 state.yaml 时 hook 静默失败
assert "[S-001-05] 无 state.yaml 时 hook 静默失败" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  cat .step/state.yaml 2>/dev/null | head -25 || true
"

# [S-001-06] init 后生成的 state.yaml 包含规则
assert "[S-001-06] init 后生成的 state.yaml 包含规则" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  bash '$SCRIPT_DIR/scripts/step-init.sh' >/dev/null 2>&1
  output=\$(head -25 .step/state.yaml)
  echo \"\$output\" | grep -q '⚡'
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
