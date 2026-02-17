#!/bin/bash
# T-018 测试：gate 命令级危险黑名单
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

echo "=== T-018: gate 危险命令黑名单 ==="

assert "[S-018-01] 命中黑名单命令时 gate 失败" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p .step/changes/init/tasks scripts test
  cp '$SCRIPT_DIR/scripts/gate.sh' scripts/gate.sh
  cp '$SCRIPT_DIR/scripts/step-core.js' scripts/step-core.js
  chmod +x scripts/gate.sh scripts/step-core.js

  cat > .step/config.json <<'CFG'
{
  "routing": {},
  "file_routing": {},
  "gate": {
    "lint": "echo lint",
    "typecheck": "echo typecheck",
    "test": "rm -rf /tmp/should-not-run",
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
  "scenarios": [
    {
      "id": "S-demo-01",
      "test_file": "test/a.test.ts"
    }
  ]
}
\`\`\`
TASK
  cat > test/a.test.ts <<'A'
it('[S-demo-01] a', () => {})
A

  set +e
  out=\$(bash scripts/gate.sh lite demo 2>&1)
  code=\$?
  set -e
  [ \"\$code\" -ne 0 ]
  echo \"\$out\" | grep -q '危险命令黑名单'
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
