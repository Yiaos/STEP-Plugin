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
  trap 'rm -rf \"\$tmpdir\"' EXIT
  mkdir -p \"\$tmpdir/.step\"
  today=\$(date -u +%Y-%m-%d)
  cat > \"\$tmpdir/.step/state.yaml\" <<INNER
project: test
last_updated: \"\${today}T12:00:00Z\"
progress_log:
  - date: \"\$today\"
    summary: test
    next_action: test
INNER
  cd \"\$tmpdir\"
  output=\$(bash '$SCRIPT_DIR/scripts/step-stop-check.sh' 2>&1)
  echo \"\$output\" | grep -q 'PASS'
"

# [S-002-02] last_updated 过期时输出 WARN
assert "[S-002-02] last_updated 过期时输出 WARN" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  mkdir -p \"\$tmpdir/.step\"
  today=\$(date -u +%Y-%m-%d)
  cat > \"\$tmpdir/.step/state.yaml\" <<INNER
project: test
last_updated: \"2020-01-01T12:00:00Z\"
progress_log:
  - date: \"\$today\"
    summary: test
    next_action: test
INNER
  cd \"\$tmpdir\"
  output=\$(bash '$SCRIPT_DIR/scripts/step-stop-check.sh' 2>&1)
  echo \"\$output\" | grep -q 'WARN'
"

# [S-002-03] progress_log 缺失时输出 WARN
assert "[S-002-03] progress_log 缺失时输出 WARN" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  mkdir -p \"\$tmpdir/.step\"
  today=\$(date -u +%Y-%m-%d)
  cat > \"\$tmpdir/.step/state.yaml\" <<INNER
project: test
last_updated: \"\${today}T12:00:00Z\"
progress_log:
  - date: \"2020-01-01\"
    summary: old
    next_action: old
INNER
  cd \"\$tmpdir\"
  output=\$(bash '$SCRIPT_DIR/scripts/step-stop-check.sh' 2>&1)
  echo \"\$output\" | grep -q 'WARN'
"

# [S-002-04] 双项缺失时输出 FAIL
assert "[S-002-04] 双项缺失时输出 FAIL" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  mkdir -p \"\$tmpdir/.step\"
  cat > \"\$tmpdir/.step/state.yaml\" <<INNER
project: test
last_updated: \"2020-01-01T12:00:00Z\"
progress_log:
  - date: \"2020-01-01\"
    summary: old
    next_action: old
INNER
  cd \"\$tmpdir\"
  output=\$(bash '$SCRIPT_DIR/scripts/step-stop-check.sh' 2>&1)
  echo \"\$output\" | grep -q 'FAIL'
"

# [S-002-05] 无 state.yaml 时 SKIP
assert "[S-002-05] 无 state.yaml 时 SKIP" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  output=\$(bash '$SCRIPT_DIR/scripts/step-stop-check.sh' 2>&1)
  echo \"\$output\" | grep -q 'SKIP'
"

# [S-002-06] 损坏 YAML 不崩溃
assert "[S-002-06] 损坏 YAML 不崩溃" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  mkdir -p \"\$tmpdir/.step\"
  echo '{{invalid yaml:::' > \"\$tmpdir/.step/state.yaml\"
  cd \"\$tmpdir\"
  # 脚本应该能运行完成（不崩溃），输出 WARN
  output=\$(bash '$SCRIPT_DIR/scripts/step-stop-check.sh' 2>&1 || true)
  echo \"\$output\" | grep -qi 'warn\|skip\|fail'
"

# [S-002-07] SKILL.md Stop hook 调用脚本
assert "[S-002-07] SKILL.md Stop hook 调用脚本" bash -c "
  grep -q 'step-stop-check' '$SCRIPT_DIR/skills/step/SKILL.md'
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
