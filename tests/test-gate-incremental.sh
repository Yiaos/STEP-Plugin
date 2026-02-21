#!/bin/bash
# T-015 测试：gate 默认增量测试
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

echo "=== T-015: gate 默认增量测试 ==="

assert "[S-015-01] gate lite 默认只传 task 声明的测试文件" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p .step/changes/init/tasks .step/changes/init/evidence scripts tests test
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
    },
    {
      "id": "S-demo-02",
      "test_file": "test/b.test.ts"
    }
  ]
}
\`\`\`
TASK

  cat > test/a.test.ts <<'A'
it('[S-demo-01] a', () => {})
A
  cat > test/b.test.ts <<'B'
it('[S-demo-02] b', () => {})
B
  cat > tests/fake-runner.sh <<'RUN'
#!/bin/bash
printf '%s\n' "$@" > .step/changes/init/evidence/test-args.txt
RUN
  chmod +x tests/fake-runner.sh

  OPENCODE_PLUGIN_ROOT="\$PWD"
  bash "\$OPENCODE_PLUGIN_ROOT/scripts/gate.sh" lite demo >/dev/null 2>&1
  grep -q 'test/a.test.ts' .step/changes/init/evidence/test-args.txt
  grep -q 'test/b.test.ts' .step/changes/init/evidence/test-args.txt
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
