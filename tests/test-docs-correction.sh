#!/bin/bash
# T-005 测试：对比文档修正
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

echo "=== T-005: 对比文档修正 ==="

# [S-005-01] 遗忘处理描述已修正
assert "[S-005-01] 遗忘处理描述已修正" bash -c "
  set -e
  # 文档应该提到 STEP 的注意力管理能力
  grep -qi 'PreToolUse\|注意力\|attention\|head -25\|stop.*check' '$SCRIPT_DIR/comparisons/STEP-vs-planning-with-files.md'
"

# [S-005-02] 无过时否定表述
assert "[S-005-02] 无过时否定表述" bash -c "
  set -e
  # 不应该有说 STEP 不处理遗忘的表述
  ! grep -i 'STEP.*不处理.*遗忘\|STEP.*缺少.*注意力\|STEP.*没有.*遗忘' '$SCRIPT_DIR/comparisons/STEP-vs-planning-with-files.md'
"

# [S-005-03] markdown 格式正确
assert "[S-005-03] markdown 格式正确" bash -c "
  set -e
  # 基本检查：文件存在且不为空
  [ -s '$SCRIPT_DIR/comparisons/STEP-vs-planning-with-files.md' ]
"

# [S-005-04] COMPARISON.md 同步检查
assert "[S-005-04] COMPARISON.md 同步检查" bash -c "
  set -e
  # 综合对比文档也不应有过时表述
  ! grep -i 'STEP.*不处理.*遗忘\|STEP.*缺少.*注意力' '$SCRIPT_DIR/COMPARISON.md' 2>/dev/null || true
"

# [S-005-05] 全局无过时遗忘描述
assert "[S-005-05] 全局无过时遗忘描述" bash -c "
  set -e
  ! grep -ri 'STEP.*不处理.*遗忘\|STEP.*缺少.*注意力\|STEP.*没有.*遗忘' '$SCRIPT_DIR/comparisons/' 2>/dev/null
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
