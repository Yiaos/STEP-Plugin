#!/bin/bash
# T-031 测试：task status 子命令

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

echo "=== T-031: task status command ==="

assert "[S-dedup-task-status-01] status matches expected" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cat > \"\$tmpdir/t.json\" <<INNER
{\"id\":\"t\",\"title\":\"t\",\"mode\":\"full\",\"status\":\"done\",\"done_when\":[],\"scenarios\":[]}
INNER
  node '$SCRIPT_DIR/scripts/step-core.js' task status --file \"\$tmpdir/t.json\" --expected done
"

assert "[S-dedup-task-status-02] status mismatch returns 1" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cat > \"\$tmpdir/t.json\" <<INNER
{\"id\":\"t\",\"title\":\"t\",\"mode\":\"full\",\"status\":\"in_progress\",\"done_when\":[],\"scenarios\":[]}
INNER
  set +e
  node '$SCRIPT_DIR/scripts/step-core.js' task status --file \"\$tmpdir/t.json\" --expected done >/dev/null 2>&1
  code=\$?
  set -e
  [ "\$code" -eq 1 ]
"

assert "[S-dedup-task-status-03] markdown json parsed correctly" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  bt=\$(printf '\\140\\140\\140')
  cat > \"\$tmpdir/t.md\" <<INNER
# t
\${bt}json task
{\"id\":\"t\",\"title\":\"t\",\"mode\":\"full\",\"status\":\"done\",\"done_when\":[],\"scenarios\":[]}
\${bt}
INNER
  node '$SCRIPT_DIR/scripts/step-core.js' task status --file \"\$tmpdir/t.md\" --expected done
"

assert "[S-dedup-task-status-04] missing file returns exit 2" bash -c "
  set -e
  set +e
  node '$SCRIPT_DIR/scripts/step-core.js' task status --file /no/such/file.md --expected done >/dev/null 2>&1
  code=\$?
  set -e
  [ "\$code" -eq 2 ]
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
