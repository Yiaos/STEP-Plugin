#!/bin/bash
# T-016 测试：gate --all 强制全量测试命令
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

echo "=== T-016: gate --all 全量测试 ==="

assert "[S-016-01] gate --all 不追加 task 测试文件参数" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p .step/changes/init/tasks .step/evidence scripts tests test
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
    "test": "bash tests/fake-runner.sh",
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
  cat > tests/fake-runner.sh <<'RUN'
#!/bin/bash
printf '%s\n' "$@" > .step/evidence/test-args.txt
RUN
  chmod +x tests/fake-runner.sh

  bash scripts/gate.sh lite demo --all >/dev/null 2>&1
  [ ! -s .step/evidence/test-args.txt ]
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
