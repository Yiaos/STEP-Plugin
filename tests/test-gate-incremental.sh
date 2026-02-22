#!/bin/bash
# T-033 测试：gate 增量测试在多段命令场景的行为

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

echo "=== T-033: gate incremental multi-segment ==="

assert "[S-gate-incremental-01] multi-segment test command supports incremental subset" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p scripts lib tests .step/changes/c1/tasks
  cp '$SCRIPT_DIR/scripts/step-core.js' scripts/step-core.js
  cp -R '$SCRIPT_DIR/lib/core' lib/core
  chmod +x scripts/step-core.js

  cat > .step/state.json <<'EOF'
{
  \"project\": \"demo\",
  \"current_phase\": \"phase-4-execution\",
  \"current_change\": \"c1\",
  \"last_updated\": \"2026-02-22T00:00:00Z\",
  \"last_agent\": \"tester\",
  \"last_session_summary\": \"\",
  \"session\": { \"mode\": \"full\" },
  \"established_patterns\": {},
  \"tasks\": { \"current\": \"demo\", \"upcoming\": [] },
  \"key_decisions\": [],
  \"known_issues\": [],
  \"constraints_quick_ref\": [],
  \"progress_log\": []
}
EOF

  cat > .step/config.json <<'EOF'
{
  \"routing\": {},
  \"file_routing\": {},
  \"gate\": {
    \"lint\": \"true\",
    \"typecheck\": \"true\",
    \"test\": \"bash tests/a.sh && bash tests/b.sh\",
    \"build\": \"true\"
  }
}
EOF

  cat > .step/changes/c1/tasks/demo.md <<'EOF'
# demo

\`\`\`json task
{
  \"id\": \"demo\",
  \"title\": \"demo\",
  \"mode\": \"full\",
  \"status\": \"in_progress\",
  \"done_when\": [],
  \"scenarios\": {
    \"happy_path\": [
      {
        \"id\": \"S-gate-incremental-01\",
        \"test_file\": \"tests/a.sh\",
        \"test_name\": \"[S-gate-incremental-01]\",
        \"test_type\": \"unit\",
        \"status\": \"not_run\"
      }
    ]
  }
}
\`\`\`
EOF

  cat > tests/a.sh <<'EOF'
#!/bin/bash
set -e
assert() {
  local _name=\"\$1\"; shift
  \"\$@\"
}
assert \"[S-gate-incremental-01]\" touch .ran-a
EOF
  chmod +x tests/a.sh

  cat > tests/b.sh <<'EOF'
#!/bin/bash
set -e
touch .ran-b
EOF
  chmod +x tests/b.sh

  out=\$(node scripts/step-core.js gate run --level lite --task demo --mode incremental --config .step/config.json 2>&1)
  echo \"\$out\" | grep -q 'test-scope: incremental'
  [ -f .ran-a ]
  [ ! -f .ran-b ]
"

assert "[S-gate-incremental-02] non-test segment falls back to full test" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p scripts lib tests .step/changes/c1/tasks
  cp '$SCRIPT_DIR/scripts/step-core.js' scripts/step-core.js
  cp -R '$SCRIPT_DIR/lib/core' lib/core
  chmod +x scripts/step-core.js

  cat > .step/state.json <<'EOF'
{
  \"project\": \"demo\",
  \"current_phase\": \"phase-4-execution\",
  \"current_change\": \"c1\",
  \"last_updated\": \"2026-02-22T00:00:00Z\",
  \"last_agent\": \"tester\",
  \"last_session_summary\": \"\",
  \"session\": { \"mode\": \"full\" },
  \"established_patterns\": {},
  \"tasks\": { \"current\": \"demo\", \"upcoming\": [] },
  \"key_decisions\": [],
  \"known_issues\": [],
  \"constraints_quick_ref\": [],
  \"progress_log\": []
}
EOF

  cat > .step/config.json <<'EOF'
{
  \"routing\": {},
  \"file_routing\": {},
  \"gate\": {
    \"lint\": \"true\",
    \"typecheck\": \"true\",
    \"test\": \"echo prepare && bash tests/a.sh && bash tests/b.sh\",
    \"build\": \"true\"
  }
}
EOF

  cat > .step/changes/c1/tasks/demo.md <<'EOF'
# demo

\`\`\`json task
{
  \"id\": \"demo\",
  \"title\": \"demo\",
  \"mode\": \"full\",
  \"status\": \"in_progress\",
  \"done_when\": [],
  \"scenarios\": {
    \"happy_path\": [
      {
        \"id\": \"S-gate-incremental-02\",
        \"test_file\": \"tests/a.sh\",
        \"test_name\": \"[S-gate-incremental-02]\",
        \"test_type\": \"unit\",
        \"status\": \"not_run\"
      }
    ]
  }
}
\`\`\`
EOF

  cat > tests/a.sh <<'EOF'
#!/bin/bash
set -e
assert() {
  local _name=\"\$1\"; shift
  \"\$@\"
}
assert \"[S-gate-incremental-02]\" touch .ran-a
EOF
  chmod +x tests/a.sh

  cat > tests/b.sh <<'EOF'
#!/bin/bash
set -e
touch .ran-b
EOF
  chmod +x tests/b.sh

  out=\$(node scripts/step-core.js gate run --level lite --task demo --mode incremental --config .step/config.json 2>&1)
  echo \"\$out\" | grep -q '增量测试未生效（multi-segment-non-test-segment）'
  echo \"\$out\" | grep -q 'test-scope: all'
  [ -f .ran-a ]
  [ -f .ran-b ]
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
