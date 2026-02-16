#!/bin/bash
# T-011 测试：step-core 校验与任务解析
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

echo "=== T-011: step-core 校验与任务解析 ==="

# [S-011-01] state.yaml 校验通过
assert "[S-011-01] state.yaml 校验通过" bash -c "
  node '$SCRIPT_DIR/scripts/step-core.js' validate state --file '$SCRIPT_DIR/.step/state.yaml'
"

# [S-011-02] 损坏 state.yaml 校验失败
assert "[S-011-02] 损坏 state.yaml 校验失败" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  bad=\"\$tmpdir/bad-state.yaml\"
  cat > \"\$bad\" <<'EOF'
project: x
tasks: {}
EOF
  set +e
  node '$SCRIPT_DIR/scripts/step-core.js' validate state --file \"\$bad\" >/dev/null 2>&1
  code=\$?
  set -e
  [ \"\$code\" -ne 0 ]
"

# [S-011-03] task test-files 输出列表
assert "[S-011-03] task test-files 输出 JSON" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p .step/changes/init/tasks test
  cat > .step/changes/init/tasks/demo.yaml <<'EOF'
id: demo
title: demo
mode: full
status: planned
done_when: []
scenarios:
  happy_path:
    - id: S-demo-01
      test_file: test/demo.test.ts
EOF
  out=\$(node '$SCRIPT_DIR/scripts/step-core.js' task test-files --task demo --change init --json)
  echo \"\$out\" | grep -q 'test/demo.test.ts'
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
