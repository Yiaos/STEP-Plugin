#!/bin/bash
# T-013 测试：step-stop-check 严格模式退出码
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

echo "=== T-013: step-stop-check 严格模式退出码 ==="

# [S-013-01] 严格模式下 FAIL 返回非0
assert "[S-013-01] strict=true 时 FAIL 返回非0" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p .step
  cat > .step/state.json <<'EOF'
{
  "project": "demo",
  "current_phase": "phase-4-execution",
  "current_change": "init",
  "last_updated": "2000-01-01",
  "last_agent": "tester",
  "last_session_summary": "",
  "established_patterns": {},
  "tasks": {
    "current": null,
    "upcoming": []
  },
  "key_decisions": [],
  "known_issues": [],
  "constraints_quick_ref": [],
  "progress_log": []
}
EOF
  set +e
  STEP_STOP_STRICT=true bash '$SCRIPT_DIR/scripts/step-stop-check.sh' >/dev/null 2>&1
  code=\$?
  set -e
  [ \"\$code\" -ne 0 ]
"

# [S-013-02] 非严格模式下 FAIL 返回0
assert "[S-013-02] strict=false 时 FAIL 返回0" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p .step
  cat > .step/state.json <<'EOF'
{
  "project": "demo",
  "current_phase": "phase-4-execution",
  "current_change": "init",
  "last_updated": "2000-01-01",
  "last_agent": "tester",
  "last_session_summary": "",
  "established_patterns": {},
  "tasks": {
    "current": null,
    "upcoming": []
  },
  "key_decisions": [],
  "known_issues": [],
  "constraints_quick_ref": [],
  "progress_log": []
}
EOF
  STEP_STOP_STRICT=false bash '$SCRIPT_DIR/scripts/step-stop-check.sh' >/dev/null 2>&1
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
