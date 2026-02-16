#!/bin/bash
# T-009 测试：SessionStart hook 注入策略
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

echo "=== T-009: SessionStart hook 注入策略 ==="

# [S-009-01] phase-4 时注入任务 + findings，progress_log 仅保留最近3条
assert "[S-009-01] phase-4 注入任务并裁剪 progress_log" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p .step/changes/init/tasks
  cat > .step/state.yaml <<'STATE'
current_phase: "phase-4-execution"
current_change: "init"
tasks:
  current: "sample-task"
progress_log:
  - date: "2026-02-16"
    summary: s1
  - date: "2026-02-15"
    summary: s2
  - date: "2026-02-14"
    summary: s3
  - date: "2026-02-13"
    summary: s4
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
full baseline content
BASE
  cat > .step/config.yaml <<'CFG'
routing: {}
CFG
  output=\$(bash '$SCRIPT_DIR/hooks/session-start.sh')
  echo \"\$output\" | grep -q '当前变更 findings'
  echo \"\$output\" | grep -q 'pool_size: 5'
  echo \"\$output\" | grep -q '当前任务'
  ! echo \"\$output\" | grep -q 's4'
"

# [S-009-02] phase-2 时不注入当前任务，findings 缺失时不注入 findings 段落
assert "[S-009-02] phase-2 不注入任务且 findings 缺失时不注入段落" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p .step/changes/init/tasks
  cat > .step/state.yaml <<'STATE'
current_phase: "phase-2-design"
current_change: "init"
tasks:
  current: "sample-task"
progress_log: []
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
  ! echo \"\$output\" | grep -q '当前任务'
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
