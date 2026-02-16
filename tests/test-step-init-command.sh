#!/bin/bash
# T-017 测试：命令入口改为 /step/init
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

echo "=== T-017: /step/init 命令入口 ==="

assert "[S-017-01] 存在 commands/init.md" bash -c "
  [ -f '$SCRIPT_DIR/commands/init.md' ]
"

assert "[S-017-02] 不再存在 commands/step.md" bash -c "
  [ ! -f '$SCRIPT_DIR/commands/step.md' ]
"

assert "[S-017-03] README 使用 /step/init" bash -c "
  grep -q '/step/init' '$SCRIPT_DIR/README.md'
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
