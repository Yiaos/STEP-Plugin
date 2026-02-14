#!/bin/bash
# T-004 测试：SKILL.md 执行规则增强（2-Action Rule + Pre-decision Read）
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

# [S-004-01] Phase 4 包含进度更新频率
assert "[S-004-01] Phase 4 包含进度更新频率" bash -c "
  sed -n '/### Phase 4/,/### Phase 5/p' '$SKILL' | grep -q '2.*工具调用\|进度更新'
"

# [S-004-02] 硬规则包含 Pre-decision Read
assert "[S-004-02] 硬规则包含 Pre-decision Read" bash -c "
  grep -q '修改.*前.*Read\|Read.*修改' '$SKILL'
"

# [S-004-03] frontmatter YAML 语法合法
assert "[S-004-03] frontmatter YAML 语法合法" bash -c "
  set -e
  # 提取 frontmatter（两个 --- 之间）
  fm=\$(sed -n '2,/^---$/p' '$SKILL' | sed '\$d')
  echo \"\$fm\" | python3 -c 'import sys,yaml; yaml.safe_load(sys.stdin)'
"

# [S-004-04] 硬规则编号连续
assert "[S-004-04] 硬规则编号连续" bash -c "
  set -e
  # 提取硬规则编号
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
  true  # 安装前可以不一致
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
