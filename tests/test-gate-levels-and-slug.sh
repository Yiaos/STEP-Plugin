#!/bin/bash
# T-012 测试：gate 级别映射与 slug 强制
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

echo "=== T-012: gate 级别映射与 slug 强制 ==="

# [S-012-01] 不带 slug 直接失败
assert "[S-012-01] gate lite 缺少 slug 失败" bash -c "
  set +e
  out=\$(bash '$SCRIPT_DIR/scripts/gate.sh' lite 2>&1)
  code=\$?
  set -e
  [ \"\$code\" -ne 0 ]
  echo \"\$out\" | grep -q '必须指定 task slug'
"

# [S-012-02] quick 映射到 lite
assert "[S-012-02] quick 映射到 lite" bash -c "
  grep -q \"gate level 'quick'\" '$SCRIPT_DIR/scripts/gate.sh'
"

# [S-012-03] standard 映射到 lite
assert "[S-012-03] standard 映射到 lite" bash -c "
  grep -q \"gate level 'standard'\" '$SCRIPT_DIR/scripts/gate.sh'
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
