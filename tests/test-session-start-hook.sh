#!/bin/bash
# T-009 测试：SessionStart hook 注入 findings
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

echo "=== T-009: SessionStart hook 注入 findings ==="

# [S-009-01] findings.md 存在时被注入上下文
assert "[S-009-01] findings 注入 SessionStart 上下文" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p .step/changes/init/tasks
  cat > .step/state.yaml <<'STATE'
current_change: "init"
tasks:
  current: "sample-task"
STATE
  cat > .step/changes/init/spec.md <<'SPEC'
# Spec
SPEC
  cat > .step/changes/init/findings.md <<'FINDINGS'
# Findings
- pool_size: 5
FINDINGS
  cat > .step/changes/init/tasks/sample-task.yaml <<'TASK'
id: sample-task
TASK
  cat > .step/baseline.md <<'BASE'
# Baseline
BASE
  cat > .step/config.yaml <<'CFG'
routing: {}
CFG
  output=\$(bash '$SCRIPT_DIR/hooks/session-start.sh')
  echo \"\$output\" | grep -q '当前变更 findings'
  echo \"\$output\" | grep -q 'pool_size: 5'
"

# [S-009-02] findings.md 不存在时不注入 findings 段落
assert "[S-009-02] findings 缺失时不注入空段落" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p .step/changes/init/tasks
  cat > .step/state.yaml <<'STATE'
current_change: \"init\"
tasks:
  current: \"sample-task\"
STATE
  cat > .step/changes/init/spec.md <<'SPEC'
# Spec
SPEC
  cat > .step/changes/init/tasks/sample-task.yaml <<'TASK'
id: sample-task
TASK
  cat > .step/baseline.md <<'BASE'
# Baseline
BASE
  cat > .step/config.yaml <<'CFG'
routing: {}
CFG
  output=\$(bash '$SCRIPT_DIR/hooks/session-start.sh')
  ! echo \"\$output\" | grep -q '当前变更 findings'
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
