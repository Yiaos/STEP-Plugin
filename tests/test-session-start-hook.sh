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

assert "[S-009-01][S-session-start-fix-01][S-phased-injection-01] phase-4 注入任务并裁剪到相关规则" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p .step/changes/init/tasks
  cat > .step/state.json <<'STATE'
{
  \"project\": \"demo\",
  \"current_phase\": \"phase-4-execution\",
  \"current_change\": \"init\",
  \"last_updated\": \"2026-02-16T00:00:00Z\",
  \"last_agent\": \"tester\",
  \"last_session_summary\": \"\",
  \"session\": { \"mode\": \"full\" },
  \"established_patterns\": {},
  \"tasks\": { \"current\": \"sample-task\", \"upcoming\": [] },
  \"key_decisions\": [],
  \"known_issues\": [],
  \"constraints_quick_ref\": [],
  \"progress_log\": [
    {\"date\":\"2026-02-16\",\"summary\":\"s1\"},
    {\"date\":\"2026-02-15\",\"summary\":\"s2\"},
    {\"date\":\"2026-02-14\",\"summary\":\"s3\"},
    {\"date\":\"2026-02-13\",\"summary\":\"s4\"}
  ]
}
STATE
  cat > .step/changes/init/spec.md <<'SPEC'
# Spec
SPEC
  cat > .step/changes/init/findings.md <<'FINDINGS'
# Findings
- pool_size: 5
FINDINGS
  cat > .step/changes/init/tasks/sample-task.md <<'TASK'
# sample-task
\`\`\`json task
{\"id\":\"sample-task\",\"title\":\"sample task\",\"mode\":\"lite\",\"status\":\"planned\",\"done_when\":[],\"scenarios\":[]}
\`\`\`
TASK
  cat > .step/baseline.md <<'BASE'
# Baseline
full baseline content
BASE
  cat > .step/config.json <<'CFG'
{\"routing\":{}}
CFG
  output=\$(bash '$SCRIPT_DIR/hooks/session-start.sh')
  echo \"\$output\" | grep -q '当前变更 findings'
  echo \"\$output\" | grep -q 'pool_size: 5'
  echo \"\$output\" | grep -q '当前任务'
  ! echo \"\$output\" | grep -q 's4'
  echo \"\$output\" | grep -q 'Phase 4：TDD + gate'
  ! echo \"\$output\" | grep -q 'Phase 0/1：用户主导探索与需求确认'
"

assert "[S-009-02][S-phased-injection-02] phase-1 不注入任务且注入 phase-0-1 规则" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p .step/changes/init/tasks
  cat > .step/state.json <<'STATE'
{
  \"project\": \"demo\",
  \"current_phase\": \"phase-1-prd\",
  \"current_change\": \"init\",
  \"last_updated\": \"2026-02-16T00:00:00Z\",
  \"last_agent\": \"tester\",
  \"last_session_summary\": \"\",
  \"session\": { \"mode\": \"full\" },
  \"established_patterns\": {},
  \"tasks\": { \"current\": \"sample-task\", \"upcoming\": [] },
  \"key_decisions\": [],
  \"known_issues\": [],
  \"constraints_quick_ref\": [],
  \"progress_log\": []
}
STATE
  cat > .step/changes/init/spec.md <<'SPEC'
# Spec
SPEC
  cat > .step/baseline.md <<'BASE'
# Baseline
BASE
  cat > .step/config.json <<'CFG'
{\"routing\":{}}
CFG
  output=\$(bash '$SCRIPT_DIR/hooks/session-start.sh')
  ! echo \"\$output\" | grep -q '当前任务'
  echo \"\$output\" | grep -q 'Phase 0/1：用户主导探索与需求确认'
  ! echo \"\$output\" | grep -q 'Phase 4：TDD + gate'
"

assert "[S-session-start-fix-02] dollar signs preserved in output" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p .step/changes/init/tasks
  cat > .step/state.json <<'STATE'
{\"project\":\"demo\",\"current_phase\":\"phase-4-execution\",\"current_change\":\"init\",\"last_updated\":\"2026-02-16T00:00:00Z\",\"last_agent\":\"tester\",\"last_session_summary\":\"\",\"session\":{\"mode\":\"full\"},\"established_patterns\":{},\"tasks\":{\"current\":null,\"upcoming\":[]},\"key_decisions\":[],\"known_issues\":[],\"constraints_quick_ref\":[],\"progress_log\":[]}
STATE
  cat > .step/changes/init/spec.md <<'SPEC'
# Spec
SPEC
  cat > .step/baseline.md <<'BASE'
\$HOME and \$(date) should stay literal
BASE
  cat > .step/config.json <<'CFG'
{\"routing\":{}}
CFG
  output=\$(bash '$SCRIPT_DIR/hooks/session-start.sh')
  echo \"\$output\" | grep -q '\$HOME'
  echo \"\$output\" | grep -q '\$(date)'
"

assert "[S-session-start-fix-03] missing state exits gracefully" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  out=\$(bash '$SCRIPT_DIR/hooks/session-start.sh')
  echo \"\$out\" | grep -q '\"additionalContext\": \"\"'
"

assert "[S-session-start-fix-04] special chars escaped correctly" bash -c '
  set -e
  tmpdir=$(mktemp -d)
  trap "rm -rf \"$tmpdir\"" EXIT
  cd "$tmpdir"
  mkdir -p .step/changes/init/tasks
  cat > .step/state.json <<"STATE"
{"project":"demo","current_phase":"phase-4-execution","current_change":"init","last_updated":"2026-02-16T00:00:00Z","last_agent":"tester","last_session_summary":"","session":{"mode":"full"},"established_patterns":{},"tasks":{"current":null,"upcoming":[]},"key_decisions":[],"known_issues":[],"constraints_quick_ref":[],"progress_log":[]}
STATE
  cat > .step/changes/init/spec.md <<"SPEC"
line1 "quote" and backslash \\
line2
SPEC
  cat > .step/baseline.md <<"BASE"
# Baseline
BASE
  cat > .step/config.json <<"CFG"
{"routing":{}}
CFG
  output=$(bash '"$SCRIPT_DIR"'/hooks/session-start.sh)
  cat > check-json.js <<"JS"
const fs = require("fs")
JSON.parse(fs.readFileSync(0, "utf-8"))
JS
  printf "%s" "$output" | node check-json.js
'

assert "[S-session-start-fix-05] corrupted state handled gracefully" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p .step
  echo '{bad json' > .step/state.json
  out=\$(bash '$SCRIPT_DIR/hooks/session-start.sh')
  echo \"\$out\" | grep -q 'state.json 解析失败'
"

assert "[S-phased-injection-03] idle gets minimal sections" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p .step/changes/init
  cat > .step/state.json <<'STATE'
{\"project\":\"demo\",\"current_phase\":\"idle\",\"current_change\":\"init\",\"last_updated\":\"2026-02-16T00:00:00Z\",\"last_agent\":\"tester\",\"last_session_summary\":\"\",\"session\":{\"mode\":\"full\"},\"established_patterns\":{},\"tasks\":{\"current\":null,\"upcoming\":[]},\"key_decisions\":[],\"known_issues\":[],\"constraints_quick_ref\":[],\"progress_log\":[]}
STATE
  cat > .step/changes/init/spec.md <<'SPEC'
# Spec
SPEC
  cat > .step/baseline.md <<'BASE'
# Baseline
BASE
  cat > .step/config.json <<'CFG'
{\"routing\":{}}
CFG
  out=\$(bash '$SCRIPT_DIR/hooks/session-start.sh')
  echo \"\$out\" | grep -q 'Full 模式：phase-1/2/3 启用写锁'
  echo \"\$out\" | grep -q 'Session 结束必须更新 state.json'
  ! echo \"\$out\" | grep -q 'Phase 0/1：用户主导探索与需求确认'
  ! echo \"\$out\" | grep -q 'Phase 4：TDD + gate'
"

assert "[S-phased-injection-04] missing section marker falls back to full" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p .step
  cat > .step/state.json <<'STATE'
{\"project\":\"demo\",\"current_phase\":\"phase-4-execution\",\"current_change\":\"init\",\"last_updated\":\"2026-02-16T00:00:00Z\",\"last_agent\":\"tester\",\"last_session_summary\":\"\",\"session\":{\"mode\":\"full\"},\"established_patterns\":{},\"tasks\":{\"current\":null,\"upcoming\":[]},\"key_decisions\":[],\"known_issues\":[],\"constraints_quick_ref\":[],\"progress_log\":[]}
STATE
  cat > skill-no-sections.md <<'SKILL'
plain skill without section markers
SKILL
  out=\$(node '$SCRIPT_DIR/scripts/step-core.js' hook session-start --state .step/state.json --phase phase-4-execution --change init --task t1 --inject-task true --skill skill-no-sections.md)
  echo \"\$out\" | grep -q 'plain skill without section markers'
"

assert "[S-phased-injection-05] missing skill file handled" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p .step
  cat > .step/state.json <<'STATE'
{\"project\":\"demo\",\"current_phase\":\"phase-4-execution\",\"current_change\":\"init\",\"last_updated\":\"2026-02-16T00:00:00Z\",\"last_agent\":\"tester\",\"last_session_summary\":\"\",\"session\":{\"mode\":\"full\"},\"established_patterns\":{},\"tasks\":{\"current\":null,\"upcoming\":[]},\"key_decisions\":[],\"known_issues\":[],\"constraints_quick_ref\":[],\"progress_log\":[]}
STATE
  out=\$(node '$SCRIPT_DIR/scripts/step-core.js' hook session-start --state .step/state.json --phase phase-4-execution --change init --task t1 --inject-task true --skill /no/such/skill.md)
  echo \"\$out\" | grep -q 'hookSpecificOutput'
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
