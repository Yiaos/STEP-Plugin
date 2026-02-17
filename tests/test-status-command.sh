#!/bin/bash
# T-019 测试：status 诊断命令
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

echo "=== T-019: status 诊断命令 ==="

assert "[S-019-01] step-core status report 输出核心字段" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p .step/changes/init/tasks .step/evidence
  cat > .step/state.json <<'STATE'
{\"project\":\"demo\",\"current_phase\":\"phase-4-execution\",\"current_change\":\"init\",\"last_updated\":\"2026-02-16\",\"last_agent\":\"orchestrator\",\"last_session_summary\":\"x\",\"established_patterns\":{},\"tasks\":{\"current\":\"demo\",\"upcoming\":[]},\"key_decisions\":[],\"known_issues\":[],\"constraints_quick_ref\":[],\"progress_log\":[]}
STATE
  cat > .step/changes/init/tasks/demo.md <<'TASK'
# demo
\`\`\`json task
{\"id\":\"demo\",\"title\":\"demo\",\"mode\":\"lite\",\"status\":\"done\",\"done_when\":[],\"scenarios\":[]}
\`\`\`
TASK
  cat > .step/evidence/demo-gate.json <<'E'
{\"passed\": true}
E
  out=\$(node '$SCRIPT_DIR/scripts/step-core.js' status report --root .step)
  echo \"\$out\" | grep -q 'STEP Status'
  echo \"\$out\" | grep -q 'Phase:'
  echo \"\$out\" | grep -q 'Progress: 1/1'
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
