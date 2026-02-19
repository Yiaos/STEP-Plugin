#!/bin/bash
# T-021 测试：quick 模式升级留痕
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

echo "=== T-021: quick 升级留痕 ==="

assert "[S-021-01] gate evidence 记录 escalated 信息" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p .step/changes/init/tasks .step/changes/init/evidence scripts
  cp '$SCRIPT_DIR/scripts/gate.sh' scripts/gate.sh
  cp '$SCRIPT_DIR/scripts/step-core.js' scripts/step-core.js
  chmod +x scripts/gate.sh scripts/step-core.js

  cat > .step/config.json <<'CFG'
{
  "routing": {},
  "file_routing": {},
  "gate": {
    "lint": "echo lint",
    "typecheck": "echo tc",
    "test": "echo test",
    "build": "echo build"
  }
}
CFG

  cat > .step/changes/init/tasks/demo.md <<'TASK'
# demo
\`\`\`json task
{
  "id": "demo",
  "title": "demo",
  "mode": "lite",
  "status": "planned",
  "done_when": [],
  "scenarios": []
}
\`\`\`
TASK

  bash scripts/gate.sh quick demo --quick-reason "small refactor" --escalated true --escalation-reason "touch behavior" >/dev/null 2>&1
  grep -q 'escalated' .step/changes/init/evidence/demo-gate.json
  grep -q 'true' .step/changes/init/evidence/demo-gate.json
  grep -q 'escalation_reason' .step/changes/init/evidence/demo-gate.json
  grep -q 'touch behavior' .step/changes/init/evidence/demo-gate.json
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
