#!/bin/bash
# T-029 测试：change cancel 机制

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

echo "=== T-029: cancel mechanism ==="

assert "[S-cancel-mechanism-01] cancel resets state" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  mkdir -p \"\$tmpdir/.step/changes/c1/tasks\" \"\$tmpdir/.step/archive\" \"\$tmpdir/scripts\"
  cp '$SCRIPT_DIR/templates/state.json' \"\$tmpdir/.step/state.json\"
  cp '$SCRIPT_DIR/scripts/step-manager.sh' \"\$tmpdir/scripts/step-manager.sh\"
  cp '$SCRIPT_DIR/scripts/step-core.js' \"\$tmpdir/scripts/step-core.js\"
  chmod +x \"\$tmpdir/scripts/step-manager.sh\" \"\$tmpdir/scripts/step-core.js\"
  node -e 'const fs=require(\"fs\");const f=process.argv[1];const s=JSON.parse(fs.readFileSync(f,\"utf-8\"));s.current_phase=\"phase-2-tech-design\";s.current_change=\"c1\";s.tasks.current=\"t1\";s.session={mode:\"full\"};fs.writeFileSync(f,JSON.stringify(s,null,2)+\"\\n\")' \"\$tmpdir/.step/state.json\"
  printf '\`\`\`json task\\n{"id":"t1","title":"t1","mode":"full","status":"planned","done_when":[],"scenarios":[]}\\n\`\`\`\\n' > \"\$tmpdir/.step/changes/c1/tasks/t1.md\"
  (cd \"\$tmpdir\" && bash scripts/step-manager.sh cancel)
  node -e 'const fs=require(\"fs\");const s=JSON.parse(fs.readFileSync(process.argv[1],\"utf-8\"));if(s.current_phase!==\"idle\") process.exit(1);if(s.current_change!==\"\") process.exit(2);if(s.tasks.current!==null) process.exit(3)' \"\$tmpdir/.step/state.json\"
"

assert "[S-cancel-mechanism-02] cancelled change archived with suffix" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  mkdir -p \"\$tmpdir/.step/changes/c1/tasks\" \"\$tmpdir/.step/archive\" \"\$tmpdir/scripts\"
  cp '$SCRIPT_DIR/templates/state.json' \"\$tmpdir/.step/state.json\"
  cp '$SCRIPT_DIR/scripts/step-manager.sh' \"\$tmpdir/scripts/step-manager.sh\"
  cp '$SCRIPT_DIR/scripts/step-core.js' \"\$tmpdir/scripts/step-core.js\"
  chmod +x \"\$tmpdir/scripts/step-manager.sh\" \"\$tmpdir/scripts/step-core.js\"
  node -e 'const fs=require(\"fs\");const f=process.argv[1];const s=JSON.parse(fs.readFileSync(f,\"utf-8\"));s.current_phase=\"phase-3-planning\";s.current_change=\"c1\";s.tasks.current=\"t1\";fs.writeFileSync(f,JSON.stringify(s,null,2)+\"\\n\")' \"\$tmpdir/.step/state.json\"
  printf '\`\`\`json task\\n{"id":"t1","title":"t1","mode":"full","status":"planned","done_when":[],"scenarios":[]}\\n\`\`\`\\n' > \"\$tmpdir/.step/changes/c1/tasks/t1.md\"
  (cd \"\$tmpdir\" && bash scripts/step-manager.sh cancel)
  ls \"\$tmpdir/.step/archive\" | grep -q 'c1-cancelled'
"

assert "[S-cancel-mechanism-03] cancel on idle is no-op" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  mkdir -p \"\$tmpdir/.step\" \"\$tmpdir/scripts\"
  cp '$SCRIPT_DIR/templates/state.json' \"\$tmpdir/.step/state.json\"
  cp '$SCRIPT_DIR/scripts/step-manager.sh' \"\$tmpdir/scripts/step-manager.sh\"
  cp '$SCRIPT_DIR/scripts/step-core.js' \"\$tmpdir/scripts/step-core.js\"
  chmod +x \"\$tmpdir/scripts/step-manager.sh\" \"\$tmpdir/scripts/step-core.js\"
  node -e 'const fs=require(\"fs\");const f=process.argv[1];const s=JSON.parse(fs.readFileSync(f,\"utf-8\"));s.current_phase=\"idle\";s.current_change=\"\";fs.writeFileSync(f,JSON.stringify(s,null,2)+\"\\n\")' \"\$tmpdir/.step/state.json\"
  (cd \"\$tmpdir\" && bash scripts/step-manager.sh cancel)
"

assert "[S-cancel-mechanism-04] cannot cancel done change" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  mkdir -p \"\$tmpdir/.step\" \"\$tmpdir/scripts\"
  cp '$SCRIPT_DIR/scripts/step-manager.sh' \"\$tmpdir/scripts/step-manager.sh\"
  cp '$SCRIPT_DIR/scripts/step-core.js' \"\$tmpdir/scripts/step-core.js\"
  chmod +x \"\$tmpdir/scripts/step-manager.sh\" \"\$tmpdir/scripts/step-core.js\"
  cat > \"\$tmpdir/.step/state.json\" <<'STATE'
{
  \"project\": \"demo\",
  \"current_phase\": \"done\",
  \"current_change\": \"c1\",
  \"last_updated\": \"2026-02-22T00:00:00Z\",
  \"last_agent\": \"tester\",
  \"last_session_summary\": \"\",
  \"session\": { \"mode\": \"full\" },
  \"established_patterns\": {},
  \"tasks\": { \"current\": \"t1\", \"upcoming\": [] },
  \"key_decisions\": [],
  \"known_issues\": [],
  \"constraints_quick_ref\": [],
  \"progress_log\": []
}
STATE
  set +e
  out=\$(cd \"\$tmpdir\" && bash scripts/step-manager.sh cancel 2>&1)
  code=\$?
  set -e
  [ \"\$code\" -ne 0 ]
  echo \"\$out\" | grep -q '不能取消已完成变更'
"

assert "[S-cancel-mechanism-05] missing change dir handled" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  mkdir -p \"\$tmpdir/.step\" \"\$tmpdir/scripts\"
  cp '$SCRIPT_DIR/scripts/step-manager.sh' \"\$tmpdir/scripts/step-manager.sh\"
  cp '$SCRIPT_DIR/scripts/step-core.js' \"\$tmpdir/scripts/step-core.js\"
  chmod +x \"\$tmpdir/scripts/step-manager.sh\" \"\$tmpdir/scripts/step-core.js\"
  cat > \"\$tmpdir/.step/state.json\" <<'STATE'
{
  \"project\": \"demo\",
  \"current_phase\": \"phase-3-planning\",
  \"current_change\": \"missing-change\",
  \"last_updated\": \"2026-02-22T00:00:00Z\",
  \"last_agent\": \"tester\",
  \"last_session_summary\": \"\",
  \"session\": { \"mode\": \"full\" },
  \"established_patterns\": {},
  \"tasks\": { \"current\": \"t1\", \"upcoming\": [] },
  \"key_decisions\": [],
  \"known_issues\": [],
  \"constraints_quick_ref\": [],
  \"progress_log\": []
}
STATE
  out=\$(cd \"\$tmpdir\" && bash scripts/step-manager.sh cancel)
  echo \"\$out\" | grep -q '已取消变更'
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
