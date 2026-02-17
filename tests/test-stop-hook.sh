#!/bin/bash
# T-002 测试：Stop hook 脚本化
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

echo "=== T-002: Stop hook 脚本化 ==="

# [S-002-01] 状态完整时输出 PASS
assert "[S-002-01] 状态完整时输出 PASS" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf "\$tmpdir"' EXIT
  mkdir -p "\$tmpdir/.step"
  today=\$(date -u +%Y-%m-%d)
  cat > "\$tmpdir/.step/state.json" <<INNER
{
  \"project\": \"test\",
  \"current_phase\": \"phase-4-execution\",
  \"current_change\": \"init\",
  \"last_updated\": \"\${today}T12:00:00Z\",
  \"last_agent\": \"tester\",
  \"last_session_summary\": \"\",
  \"established_patterns\": {},
  \"tasks\": {
    \"current\": null,
    \"upcoming\": []
  },
  \"key_decisions\": [],
  \"known_issues\": [],
  \"constraints_quick_ref\": [],
  \"progress_log\": [
    {
      \"date\": \"\$today\",
      \"summary\": \"test\",
      \"next_action\": \"test\"
    }
  ]
}
INNER
  cd "\$tmpdir"
  output=\$(bash '$SCRIPT_DIR/scripts/step-stop-check.sh' 2>&1)
  echo "\$output" | grep -q 'PASS'
"

# [S-002-02] last_updated 过期时输出 WARN
assert "[S-002-02] last_updated 过期时输出 WARN" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf "\$tmpdir"' EXIT
  mkdir -p "\$tmpdir/.step"
  today=\$(date -u +%Y-%m-%d)
  cat > "\$tmpdir/.step/state.json" <<INNER
{
  \"project\": \"test\",
  \"current_phase\": \"phase-4-execution\",
  \"current_change\": \"init\",
  \"last_updated\": \"2020-01-01T12:00:00Z\",
  \"last_agent\": \"tester\",
  \"last_session_summary\": \"\",
  \"established_patterns\": {},
  \"tasks\": {
    \"current\": null,
    \"upcoming\": []
  },
  \"key_decisions\": [],
  \"known_issues\": [],
  \"constraints_quick_ref\": [],
  \"progress_log\": [
    {
      \"date\": \"\$today\",
      \"summary\": \"test\",
      \"next_action\": \"test\"
    }
  ]
}
INNER
  cd "\$tmpdir"
  output=\$(bash '$SCRIPT_DIR/scripts/step-stop-check.sh' 2>&1)
  echo "\$output" | grep -q 'WARN'
"

# [S-002-03] progress_log 缺失时输出 WARN
assert "[S-002-03] progress_log 缺失时输出 WARN" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf "\$tmpdir"' EXIT
  mkdir -p "\$tmpdir/.step"
  today=\$(date -u +%Y-%m-%d)
  cat > "\$tmpdir/.step/state.json" <<INNER
{
  \"project\": \"test\",
  \"current_phase\": \"phase-4-execution\",
  \"current_change\": \"init\",
  \"last_updated\": \"\${today}T12:00:00Z\",
  \"last_agent\": \"tester\",
  \"last_session_summary\": \"\",
  \"established_patterns\": {},
  \"tasks\": {
    \"current\": null,
    \"upcoming\": []
  },
  \"key_decisions\": [],
  \"known_issues\": [],
  \"constraints_quick_ref\": [],
  \"progress_log\": [
    {
      \"date\": \"2020-01-01\",
      \"summary\": \"old\",
      \"next_action\": \"old\"
    }
  ]
}
INNER
  cd "\$tmpdir"
  output=\$(bash '$SCRIPT_DIR/scripts/step-stop-check.sh' 2>&1)
  echo "\$output" | grep -q 'WARN'
"

# [S-002-04] 双项缺失时输出 FAIL 且返回非0
assert "[S-002-04] 双项缺失时输出 FAIL" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf "\$tmpdir"' EXIT
  mkdir -p "\$tmpdir/.step"
  cat > "\$tmpdir/.step/state.json" <<INNER
{
  \"project\": \"test\",
  \"current_phase\": \"phase-4-execution\",
  \"current_change\": \"init\",
  \"last_updated\": \"2020-01-01T12:00:00Z\",
  \"last_agent\": \"tester\",
  \"last_session_summary\": \"\",
  \"established_patterns\": {},
  \"tasks\": {
    \"current\": null,
    \"upcoming\": []
  },
  \"key_decisions\": [],
  \"known_issues\": [],
  \"constraints_quick_ref\": [],
  \"progress_log\": [
    {
      \"date\": \"2020-01-01\",
      \"summary\": \"old\",
      \"next_action\": \"old\"
    }
  ]
}
INNER
  cd "\$tmpdir"
  set +e
  output=\$(bash '$SCRIPT_DIR/scripts/step-stop-check.sh' 2>&1)
  code=\$?
  set -e
  [ "\$code" -ne 0 ]
  echo "\$output" | grep -q 'FAIL'
"

# [S-002-05] 无 state.json 时 SKIP
assert "[S-002-05] 无 state.json 时 SKIP" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf "\$tmpdir"' EXIT
  cd "\$tmpdir"
  output=\$(bash '$SCRIPT_DIR/scripts/step-stop-check.sh' 2>&1)
  echo "\$output" | grep -q 'SKIP'
"

# [S-002-06] 损坏 JSON 不崩溃
assert "[S-002-06] 损坏 JSON 不崩溃" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf "\$tmpdir"' EXIT
  mkdir -p "\$tmpdir/.step"
  echo '{invalid json:::' > "\$tmpdir/.step/state.json"
  cd "\$tmpdir"
  output=\$(bash '$SCRIPT_DIR/scripts/step-stop-check.sh' 2>&1 || true)
  echo "\$output" | grep -qi 'warn\|skip\|fail'
"

# [S-002-07] SKILL.md Stop hook 调用脚本
assert "[S-002-07] SKILL.md Stop hook 调用脚本" bash -c "
  grep -q 'step-stop-check' '$SCRIPT_DIR/skills/step/SKILL.md'
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
