#!/bin/bash
# T-028 测试：workflow 文档拆分

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

echo "=== T-028: workflow split ==="

assert "[S-split-workflow-doc-01] docs 分拆文件存在且非空" bash -c "
  [ -s '$SCRIPT_DIR/docs/examples.md' ]
  [ -s '$SCRIPT_DIR/docs/hooks.md' ]
  [ -s '$SCRIPT_DIR/docs/design-notes.md' ]
"

assert "[S-split-workflow-doc-03] WORKFLOW 提供分拆文档入口" bash -c "
  grep -q 'docs/examples.md' '$SCRIPT_DIR/WORKFLOW.md'
  grep -q 'docs/hooks.md' '$SCRIPT_DIR/WORKFLOW.md'
  grep -q 'docs/design-notes.md' '$SCRIPT_DIR/WORKFLOW.md'
"

assert "[S-split-workflow-doc-02] docs files exist and non-empty" bash -c "
  [ -s '$SCRIPT_DIR/docs/examples.md' ]
  [ -s '$SCRIPT_DIR/docs/hooks.md' ]
  [ -s '$SCRIPT_DIR/docs/design-notes.md' ]
"

assert "[S-split-workflow-doc-04] no content lost in split" bash -c "
  grep -q 'Lite Mode' '$SCRIPT_DIR/docs/examples.md'
  grep -q 'SessionStart' '$SCRIPT_DIR/docs/hooks.md'
  grep -q '反馈' '$SCRIPT_DIR/docs/design-notes.md'
  grep -q 'docs/examples.md' '$SCRIPT_DIR/WORKFLOW.md'
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
