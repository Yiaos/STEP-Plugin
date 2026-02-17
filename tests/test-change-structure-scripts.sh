#!/bin/bash
# T-008 测试：changes 结构下脚本行为
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

echo "=== T-008: changes 结构下脚本行为 ==="

# [S-008-01] scenario-check 优先使用 current_change
assert "[S-008-01] scenario-check 优先使用 current_change" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf "\$tmpdir"' EXIT
  cd "\$tmpdir"
  mkdir -p .step/changes/change-a/tasks .step/changes/change-b/tasks test
  cat > .step/changes/change-a/tasks/shared-task.md <<'Y1'
# shared-task
\`\`\`json task
{
  "id": "shared-task",
  "title": "shared task",
  "mode": "lite",
  "status": "planned",
  "done_when": [],
  "scenarios": [
    {
      "id": "S-shared-task-01",
      "test_file": "test/shared-a.test.ts"
    }
  ]
}
\`\`\`
Y1
  cat > .step/changes/change-b/tasks/shared-task.md <<'Y2'
# shared-task
\`\`\`json task
{
  "id": "shared-task",
  "title": "shared task",
  "mode": "lite",
  "status": "planned",
  "done_when": [],
  "scenarios": [
    {
      "id": "S-shared-task-01",
      "test_file": "test/shared-b.test.ts"
    }
  ]
}
\`\`\`
Y2
  cat > test/shared-a.test.ts <<'TA'
it('[S-shared-task-01] from change-a', () => {})
TA
  cat > test/shared-b.test.ts <<'TB'
it('no scenario id here', () => {})
TB
  cat > .step/state.json <<'S'
{
  "project": "demo",
  "current_phase": "phase-4-execution",
  "current_change": "change-a",
  "last_updated": "2026-02-16",
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
S
  bash '$SCRIPT_DIR/scripts/scenario-check.sh' shared-task
"

# [S-008-02] 同名任务跨变更时要求显式 change-name
assert "[S-008-02] scenario-check 同名任务要求显式 change-name" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf "\$tmpdir"' EXIT
  cd "\$tmpdir"
  mkdir -p .step/changes/change-a/tasks .step/changes/change-b/tasks test
  cat > .step/changes/change-a/tasks/shared-task.md <<'Y1'
# shared-task
\`\`\`json task
{
  "id": "shared-task",
  "title": "shared task",
  "mode": "lite",
  "status": "planned",
  "done_when": [],
  "scenarios": [
    {
      "id": "S-shared-task-01",
      "test_file": "test/shared.test.ts"
    }
  ]
}
\`\`\`
Y1
  cp .step/changes/change-a/tasks/shared-task.md .step/changes/change-b/tasks/shared-task.md
  cat > test/shared.test.ts <<'T'
it('[S-shared-task-01] ok', () => {})
T
  output=\$(bash '$SCRIPT_DIR/scripts/scenario-check.sh' shared-task 2>&1 || true)
  echo "\$output" | grep -q '请传 --change'
"

# [S-008-03] stop-check 仅提醒可归档变更数量
assert "[S-008-03] stop-check 提醒可归档变更" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf "\$tmpdir"' EXIT
  cd "\$tmpdir"
  mkdir -p .step/changes/done-change/tasks .step/changes/wip-change/tasks
  today=\$(date -u +%Y-%m-%d)
  cat > .step/state.json <<INNER
{\"project\":\"demo\",\"current_phase\":\"phase-4-execution\",\"current_change\":\"\",\"last_updated\":\"\${today}T12:00:00Z\",\"last_agent\":\"tester\",\"last_session_summary\":\"\",\"established_patterns\":{},\"tasks\":{\"current\":null,\"upcoming\":[]},\"key_decisions\":[],\"known_issues\":[],\"constraints_quick_ref\":[],\"progress_log\":[{\"date\":\"\$today\",\"summary\":\"test\",\"next_action\":\"test\"}]}
INNER
  cat > .step/changes/done-change/tasks/a.md <<'A'
# a
\`\`\`json task
{\"id\":\"a\",\"title\":\"a\",\"mode\":\"lite\",\"status\":\"done\",\"done_when\":[],\"scenarios\":[]}
\`\`\`
A
  cat > .step/changes/wip-change/tasks/b.md <<'B'
# b
\`\`\`json task
{\"id\":\"b\",\"title\":\"b\",\"mode\":\"lite\",\"status\":\"in_progress\",\"done_when\":[],\"scenarios\":[]}
\`\`\`
B
  output=\$(bash '$SCRIPT_DIR/scripts/step-stop-check.sh' 2>&1)
  echo "\$output" | grep -q '1 个变更可归档'
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
