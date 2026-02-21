#!/bin/bash
# T-020 测试：gate quick 小改动路径
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

echo "=== T-020: gate quick 路径 ==="

assert "[S-020-01] quick 仅执行轻量检查并跳过 scenario" bash -c "
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
    "typecheck": "bash -c 'exit 1'",
    "test": "bash -c 'exit 1'",
    "build": "bash -c 'exit 1'"
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
  "scenarios": [
    {
      "id": "S-demo-01",
      "test_file": "test/a.test.ts"
    }
  ]
}
\`\`\`
TASK

  OPENCODE_PLUGIN_ROOT="\$PWD"
  out=\$(bash "\$OPENCODE_PLUGIN_ROOT/scripts/gate.sh" quick demo --quick-reason "doc typo" 2>&1)
  echo \"\$out\" | grep -q 'Gate (level: quick'
  echo \"\$out\" | grep -q 'scenario-coverage: SKIPPED'
  [ -f .step/changes/init/evidence/demo-gate.json ]
  grep -q 'quick_reason' .step/changes/init/evidence/demo-gate.json
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
