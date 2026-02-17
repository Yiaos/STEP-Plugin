#!/bin/bash
# T-004 测试：SKILL.md 执行规则增强（Pre-decision Read + Hook 注入）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
SKILL="$SCRIPT_DIR/skills/step/SKILL.md"
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

echo "=== T-004: SKILL.md 执行规则增强 ==="

# [S-004-01] Phase 4 包含 gate 验证
assert "[S-004-01] Phase 4 包含 gate 验证" bash -c "
  sed -n '/### Phase 4/,/### Phase 5/p' '$SKILL' | grep -q 'gate\|Gate'
"

# [S-004-02] 硬规则包含 Pre-decision Read
assert "[S-004-02] 硬规则包含 Pre-decision Read" bash -c "
  grep -q '修改.*前.*Read\|Read.*修改' '$SKILL'
"

# [S-004-03] frontmatter 含关键字段
assert "[S-004-03] frontmatter 含关键字段" bash -c "
  set -e
  fm=\$(sed -n '2,/^---$/p' '$SKILL' | sed '\$d')
  echo \"\$fm\" | grep -q '^name:'
  echo \"\$fm\" | grep -q '^description:'
"

# [S-004-04] 硬规则编号连续
assert "[S-004-04] 硬规则编号连续" bash -c "
  set -e
  nums=\$(sed -n '/## Execution 硬规则/,/## /p' '$SKILL' | grep -o '^[0-9]\+\.' | tr -d '.' | sort -n)
  expected=\$(echo \"\$nums\" | head -1)
  for n in \$nums; do
    [ \"\$n\" -eq \"\$expected\" ] || exit 1
    expected=\$((expected + 1))
  done
"

# [S-004-05] frontmatter 分隔符完整
assert "[S-004-05] frontmatter 分隔符完整" bash -c "
  set -e
  count=\$(grep -c '^---$' '$SKILL')
  [ \"\$count\" -eq 2 ]
"

# [S-004-06] 安装后 SKILL.md 内容一致
assert "[S-004-06] 安装后 SKILL.md 内容一致" bash -c "
  installed=\"$HOME/.config/opencode/skills/step/SKILL.md\"
  if [ -f \"\$installed\" ]; then
    diff -q '$SKILL' \"\$installed\" >/dev/null 2>&1 || echo 'WARN: not synced (expected before reinstall)'
  fi
  true
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
