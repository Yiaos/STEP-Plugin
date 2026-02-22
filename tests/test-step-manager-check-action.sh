#!/bin/bash
# T-022 测试：step-manager check-action 全局黑名单检查
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

echo "=== T-022: step-manager check-action ==="

assert "[S-stabilize-step-trigger-enforcement-01] step-manager doctor health pass" bash -c "
  set -e
  bash '$SCRIPT_DIR/scripts/step-manager.sh' doctor
"

assert "[S-stabilize-step-trigger-enforcement-02] check-action blocks dangerous command" bash -c "
  set +e
  out=\$(bash '$SCRIPT_DIR/scripts/step-manager.sh' check-action --tool Bash --command 'rm -rf /tmp/test' 2>&1)
  code=\$?
  set -e
  [ \"\$code\" -ne 0 ]
  echo \"\$out\" | grep -q '危险命令黑名单'
"

assert "[S-stabilize-step-trigger-enforcement-03] empty command allowed" bash -c "
  set -e
  bash '$SCRIPT_DIR/scripts/step-manager.sh' check-action --tool Bash --command ''
"

assert "[S-stabilize-step-trigger-enforcement-04] fallback dangerous list" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  mkdir -p \"\$tmpdir/scripts\"
  cp '$SCRIPT_DIR/scripts/step-manager.sh' \"\$tmpdir/scripts/step-manager.sh\"
  cp '$SCRIPT_DIR/scripts/step-core.js' \"\$tmpdir/scripts/step-core.js\"
  chmod +x \"\$tmpdir/scripts/step-manager.sh\" \"\$tmpdir/scripts/step-core.js\"
  set +e
  out=\$(bash \"\$tmpdir/scripts/step-manager.sh\" check-action --tool Bash --command 'rm -rf /tmp/test' 2>&1)
  code=\$?
  set -e
  [ \"\$code\" -ne 0 ]
  echo \"\$out\" | grep -q '危险命令黑名单'
"

assert "[S-stabilize-step-trigger-enforcement-05] absolute path dangerous command blocked" bash -c "
  set +e
  out=\$(bash '$SCRIPT_DIR/scripts/step-manager.sh' check-action --tool Bash --command '/bin/rm -rf /tmp/test' 2>&1)
  code=\$?
  set -e
  [ \"\$code\" -ne 0 ]
  echo \"\$out\" | grep -q '危险命令黑名单'
"

assert "[S-guard-single-call-04] dangerous bash blocked" bash -c "
  set +e
  out=\$(bash '$SCRIPT_DIR/scripts/step-manager.sh' check-action --tool Bash --command 'rm -rf /tmp/test' 2>&1)
  code=\$?
  set -e
  [ \"\$code\" -ne 0 ]
  echo \"\$out\" | grep -q '危险命令黑名单'
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
