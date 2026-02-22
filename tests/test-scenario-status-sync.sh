#!/bin/bash
# T-030 测试：scenario status 与 ready 校验联动

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

prepare_task() {
  local scenario_block="$1"
  node -e "const fs=require('fs');const fence=String.fromCharCode(96).repeat(3);const task={id:'t1',title:'t1',mode:'full',status:'done',scenarios:${scenario_block},done_when:[]};const md='# t1\\n\\n'+fence+'json task\\n'+JSON.stringify(task,null,2)+'\\n'+fence+'\\n';fs.writeFileSync('.step/changes/c1/tasks/t1.md',md,'utf-8')"
}

case_01() {
  (
    set -e
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT
    cd "$tmpdir"
    mkdir -p .step/changes/c1/tasks tests scripts
    cp "$SCRIPT_DIR/scripts/step-core.js" scripts/step-core.js
    cp "$SCRIPT_DIR/scripts/scenario-check.sh" scripts/scenario-check.sh
    chmod +x scripts/step-core.js scripts/scenario-check.sh
    prepare_task "{happy_path:[{id:'S-task-status-sync-01',test_file:'tests/t1.test.sh',status:'not_run'}],error_handling:[{id:'S-task-status-sync-02',test_file:'tests/t1.test.sh',status:'not_run'}]}"
    cat > tests/t1.test.sh <<'TS'
#!/bin/bash
set -e
assert() {
  local _name="$1"; shift
  "$@" >/dev/null 2>&1
}
assert "[S-task-status-sync-01]" grep -q 'S-task-status-sync-01' tests/t1.test.sh
TS
    chmod +x tests/t1.test.sh
    set +e
    bash scripts/scenario-check.sh t1 c1 >/dev/null 2>&1
    code=$?
    set -e
    [ "$code" -ne 0 ]
    grep -q 'status.*pass' .step/changes/c1/tasks/t1.md
    grep -q 'status.*fail' .step/changes/c1/tasks/t1.md
    set +e
    node scripts/step-core.js task ready --task t1 --change c1 >/dev/null 2>&1
    ready_code=$?
    set -e
    [ "$ready_code" -ne 0 ]
  )
}

case_02() {
  (
    set -e
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT
    cd "$tmpdir"
    mkdir -p .step/changes/c1/tasks tests scripts
    cp "$SCRIPT_DIR/scripts/step-core.js" scripts/step-core.js
    cp "$SCRIPT_DIR/scripts/scenario-check.sh" scripts/scenario-check.sh
    chmod +x scripts/step-core.js scripts/scenario-check.sh
    prepare_task "{happy_path:[{id:'S-task-status-sync-01',test_file:'tests/t1.test.sh',status:'not_run'}],error_handling:[{id:'S-task-status-sync-02',test_file:'tests/t1.test.sh',status:'not_run'}]}"
    cat > tests/t1.test.sh <<'TS'
#!/bin/bash
set -e
assert() {
  local _name="$1"; shift
  "$@" >/dev/null 2>&1
}
assert "[S-task-status-sync-01]" grep -q 'S-task-status-sync-01' tests/t1.test.sh
assert "[S-task-status-sync-02]" grep -q 'S-task-status-sync-02' tests/t1.test.sh
TS
    chmod +x tests/t1.test.sh
    bash scripts/scenario-check.sh t1 c1 >/dev/null 2>&1
    node scripts/step-core.js task ready --task t1 --change c1 >/dev/null
  )
}

case_03() {
  (
    set -e
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT
    cd "$tmpdir"
    mkdir -p .step/changes/c1/tasks tests scripts
    cp "$SCRIPT_DIR/scripts/step-core.js" scripts/step-core.js
    cp "$SCRIPT_DIR/scripts/scenario-check.sh" scripts/scenario-check.sh
    chmod +x scripts/step-core.js scripts/scenario-check.sh
    prepare_task "{happy_path:[{id:'S-task-status-sync-03',test_file:'tests/t1.test.sh',status:'not_run'}]}"
    cat > tests/t1.test.sh <<'TS'
#!/bin/bash
set -e
assert() {
  local _name="$1"; shift
  "$@" >/dev/null 2>&1
}
assert "[S-task-status-sync-03]" /bin/true
TS
    chmod +x tests/t1.test.sh
    set +e
    bash scripts/scenario-check.sh t1 c1 >/dev/null 2>&1
    code=$?
    set -e
    [ "$code" -ne 0 ]
  )
}

case_04() {
  (
    set -e
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT
    cd "$tmpdir"
    mkdir -p .step/changes/c1/tasks tests scripts
    cp "$SCRIPT_DIR/scripts/step-core.js" scripts/step-core.js
    cp "$SCRIPT_DIR/scripts/scenario-check.sh" scripts/scenario-check.sh
    chmod +x scripts/step-core.js scripts/scenario-check.sh
    prepare_task "{happy_path:[{id:'S-task-status-sync-04',test_file:'tests/t1.test.sh',status:'not_run'}]}"
    cat > tests/t1.test.sh <<'TS'
#!/bin/bash
set -e
pass_case() {
  return 0
}
pass_case "[S-task-status-sync-04] marker-only"
TS
    chmod +x tests/t1.test.sh
    set +e
    bash scripts/scenario-check.sh t1 c1 >/dev/null 2>&1
    code=$?
    set -e
    [ "$code" -ne 0 ]
  )
}

echo "=== T-030: scenario status sync ==="

assert "[S-task-status-sync-01] scenario-check 更新 scenario.status" case_01
assert "[S-task-status-sync-02] 所有场景 pass 后 task ready 通过" case_02
assert "[S-task-status-sync-03] trivial assert command does not count as coverage" case_03
assert "[S-task-status-sync-04] pass_case marker-only does not count" case_04

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
