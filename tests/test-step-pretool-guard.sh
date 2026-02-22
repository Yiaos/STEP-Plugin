#!/bin/bash
# T-032 测试：step-pretool-guard 单次调用与行为一致性

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

echo "=== T-032: step-pretool-guard ==="

assert "[S-guard-single-call-01] write allowed in phase-4" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p .step scripts
  cp '$SCRIPT_DIR/scripts/step-pretool-guard.sh' scripts/step-pretool-guard.sh
  cp '$SCRIPT_DIR/scripts/step-core.js' scripts/step-core.js
  chmod +x scripts/step-pretool-guard.sh scripts/step-core.js
  cat > .step/state.json <<INNER
{
  \"project\": \"demo\",
  \"current_phase\": \"phase-4-execution\",
  \"current_change\": \"init\",
  \"last_updated\": \"2026-02-21T00:00:00Z\",
  \"last_agent\": \"tester\",
  \"last_session_summary\": \"\",
  \"session\": { \"mode\": \"full\" },
  \"established_patterns\": {},
  \"tasks\": { \"current\": \"t\", \"upcoming\": [] },
  \"key_decisions\": [],
  \"known_issues\": [],
  \"constraints_quick_ref\": [],
  \"progress_log\": []
}
INNER
  cat > .step/config.json <<INNER
{
  \"enforcement\": {
    \"require_dispatch\": { \"full\": false, \"lite\": false },
    \"planning_phase_write_lock\": { \"full\": true, \"lite\": false },
    \"bypass_tools\": []
  }
}
INNER
  output=\$(OPENCODE_TOOL_NAME=Write bash scripts/step-pretool-guard.sh)
  echo \"\$output\" | grep -q '\"current_phase\": \"phase-4-execution\"'
"

assert "[S-guard-single-call-02] auto-enter from idle" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p .step scripts
  cp '$SCRIPT_DIR/scripts/step-pretool-guard.sh' scripts/step-pretool-guard.sh
  cp '$SCRIPT_DIR/scripts/step-core.js' scripts/step-core.js
  chmod +x scripts/step-pretool-guard.sh scripts/step-core.js
  cat > .step/state.json <<INNER
{
  \"project\": \"demo\",
  \"current_phase\": \"idle\",
  \"current_change\": \"\",
  \"last_updated\": \"2026-02-21T00:00:00Z\",
  \"last_agent\": \"tester\",
  \"last_session_summary\": \"\",
  \"session\": { \"mode\": \"full\" },
  \"established_patterns\": {},
  \"tasks\": { \"current\": null, \"upcoming\": [] },
  \"key_decisions\": [],
  \"known_issues\": [],
  \"constraints_quick_ref\": [],
  \"progress_log\": []
}
INNER
  cat > .step/config.json <<INNER
{
  \"enforcement\": {
    \"require_dispatch\": { \"full\": false, \"lite\": false },
    \"planning_phase_write_lock\": { \"full\": true, \"lite\": false },
    \"bypass_tools\": []
  }
}
INNER
  STEP_AUTO_ENTER=true STEP_AUTO_ENTER_MODE=full bash scripts/step-pretool-guard.sh >/dev/null
  grep -q '\"current_phase\": \"phase-0-discovery\"' .step/state.json
  grep -q '\"current_change\": \"init\"' .step/state.json
"

assert "[S-guard-single-call-03] write blocked in planning phase" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p .step scripts
  cp '$SCRIPT_DIR/scripts/step-pretool-guard.sh' scripts/step-pretool-guard.sh
  cp '$SCRIPT_DIR/scripts/step-core.js' scripts/step-core.js
  chmod +x scripts/step-pretool-guard.sh scripts/step-core.js
  cat > .step/state.json <<INNER
{
  \"project\": \"demo\",
  \"current_phase\": \"phase-1-prd\",
  \"current_change\": \"init\",
  \"last_updated\": \"2026-02-21T00:00:00Z\",
  \"last_agent\": \"tester\",
  \"last_session_summary\": \"\",
  \"session\": { \"mode\": \"full\" },
  \"established_patterns\": {},
  \"tasks\": { \"current\": null, \"upcoming\": [] },
  \"key_decisions\": [],
  \"known_issues\": [],
  \"constraints_quick_ref\": [],
  \"progress_log\": []
}
INNER
  cat > .step/config.json <<INNER
{
  \"enforcement\": {
    \"require_dispatch\": { \"full\": false, \"lite\": false },
    \"planning_phase_write_lock\": { \"full\": true, \"lite\": false },
    \"bypass_tools\": []
  }
}
INNER
  set +e
  out=\$(OPENCODE_TOOL_NAME=Write bash scripts/step-pretool-guard.sh 2>&1)
  code=\$?
  set -e
  [ \"\$code\" -ne 0 ]
  echo \"\$out\" | grep -q '已启用写锁'
"

assert "[S-guard-single-call-05] no state file passes through" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p scripts
  cp '$SCRIPT_DIR/scripts/step-pretool-guard.sh' scripts/step-pretool-guard.sh
  cp '$SCRIPT_DIR/scripts/step-core.js' scripts/step-core.js
  chmod +x scripts/step-pretool-guard.sh scripts/step-core.js
  bash scripts/step-pretool-guard.sh
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
