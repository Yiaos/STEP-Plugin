#!/bin/bash
# T-026 测试：execution dispatch enforcement

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

echo "=== T-026: execution dispatch enforcement ==="

assert "[S-agent-enforce-01] full mode phase-4 blocks direct Write" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  mkdir -p \"\$tmpdir/.step\" \"\$tmpdir/scripts\"
  cp '$SCRIPT_DIR/templates/state.json' \"\$tmpdir/.step/state.json\"
  cp '$SCRIPT_DIR/templates/config.json' \"\$tmpdir/.step/config.json\"
  cp '$SCRIPT_DIR/scripts/step-core.js' \"\$tmpdir/scripts/step-core.js\"
  cp '$SCRIPT_DIR/scripts/step-pretool-guard.sh' \"\$tmpdir/scripts/step-pretool-guard.sh\"
  chmod +x \"\$tmpdir/scripts/step-core.js\" \"\$tmpdir/scripts/step-pretool-guard.sh\"
  node -e 'const fs=require(\"fs\");const f=process.argv[1];const s=JSON.parse(fs.readFileSync(f,\"utf-8\"));s.current_phase=\"phase-4-execution\";s.session={mode: \"full\"};fs.writeFileSync(f,JSON.stringify(s,null,2)+\"\\n\")' \"\$tmpdir/.step/state.json\"
  set +e
  out=\$(cd \"\$tmpdir\" && OPENCODE_TOOL_NAME=Write bash scripts/step-pretool-guard.sh 2>&1)
  code=\$?
  set -e
  [ \"\$code\" -ne 0 ]
  echo \"\$out\" | grep -q 'execution dispatch'
"

assert "[S-agent-enforce-03] bypass_tools allows Write" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  mkdir -p \"\$tmpdir/.step\" \"\$tmpdir/scripts\"
  cp '$SCRIPT_DIR/templates/state.json' \"\$tmpdir/.step/state.json\"
  cp '$SCRIPT_DIR/templates/config.json' \"\$tmpdir/.step/config.json\"
  cp '$SCRIPT_DIR/scripts/step-core.js' \"\$tmpdir/scripts/step-core.js\"
  cp '$SCRIPT_DIR/scripts/step-pretool-guard.sh' \"\$tmpdir/scripts/step-pretool-guard.sh\"
  chmod +x \"\$tmpdir/scripts/step-core.js\" \"\$tmpdir/scripts/step-pretool-guard.sh\"
  node -e 'const fs=require(\"fs\");const sf=process.argv[1];const cf=process.argv[2];const s=JSON.parse(fs.readFileSync(sf,\"utf-8\"));s.current_phase=\"phase-4-execution\";s.session={mode:\"full\"};fs.writeFileSync(sf,JSON.stringify(s,null,2)+\"\\n\");const cfg=JSON.parse(fs.readFileSync(cf,\"utf-8\"));cfg.enforcement=cfg.enforcement||{};cfg.enforcement.bypass_tools=[\"Write\"];fs.writeFileSync(cf,JSON.stringify(cfg,null,2)+\"\\n\")' \"\$tmpdir/.step/state.json\" \"\$tmpdir/.step/config.json\"
  cd \"\$tmpdir\"
  OPENCODE_TOOL_NAME=Write bash scripts/step-pretool-guard.sh
"

assert "[S-agent-enforce-02] execution agent Write allowed" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  mkdir -p \"\$tmpdir/.step\" \"\$tmpdir/scripts\"
  cp '$SCRIPT_DIR/templates/state.json' \"\$tmpdir/.step/state.json\"
  cp '$SCRIPT_DIR/templates/config.json' \"\$tmpdir/.step/config.json\"
  cp '$SCRIPT_DIR/scripts/step-core.js' \"\$tmpdir/scripts/step-core.js\"
  cp '$SCRIPT_DIR/scripts/step-pretool-guard.sh' \"\$tmpdir/scripts/step-pretool-guard.sh\"
  chmod +x \"\$tmpdir/scripts/step-core.js\" \"\$tmpdir/scripts/step-pretool-guard.sh\"
  node -e 'const fs=require(\"fs\");const f=process.argv[1];const s=JSON.parse(fs.readFileSync(f,\"utf-8\"));s.current_phase=\"phase-4-execution\";s.session={mode:\"full\"};fs.writeFileSync(f,JSON.stringify(s,null,2)+\"\\n\")' \"\$tmpdir/.step/state.json\"
  cd \"\$tmpdir\"
  OPENCODE_TOOL_NAME=Write OPENCODE_SUBAGENT_TYPE=step-developer bash scripts/step-pretool-guard.sh
"

assert "[S-agent-enforce-04] lite mode allows direct Write" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  mkdir -p \"\$tmpdir/.step\" \"\$tmpdir/scripts\"
  cp '$SCRIPT_DIR/templates/state.json' \"\$tmpdir/.step/state.json\"
  cp '$SCRIPT_DIR/templates/config.json' \"\$tmpdir/.step/config.json\"
  cp '$SCRIPT_DIR/scripts/step-core.js' \"\$tmpdir/scripts/step-core.js\"
  cp '$SCRIPT_DIR/scripts/step-pretool-guard.sh' \"\$tmpdir/scripts/step-pretool-guard.sh\"
  chmod +x \"\$tmpdir/scripts/step-core.js\" \"\$tmpdir/scripts/step-pretool-guard.sh\"
  node -e 'const fs=require(\"fs\");const f=process.argv[1];const s=JSON.parse(fs.readFileSync(f,\"utf-8\"));s.current_phase=\"lite-l2-execution\";s.session={mode:\"lite\"};fs.writeFileSync(f,JSON.stringify(s,null,2)+\"\\n\")' \"\$tmpdir/.step/state.json\"
  cd \"\$tmpdir\"
  OPENCODE_TOOL_NAME=Write bash scripts/step-pretool-guard.sh
"

assert "[S-agent-enforce-05] missing enforcement config defaults allow" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  mkdir -p \"\$tmpdir/.step\" \"\$tmpdir/scripts\"
  cp '$SCRIPT_DIR/templates/state.json' \"\$tmpdir/.step/state.json\"
  cp '$SCRIPT_DIR/templates/config.json' \"\$tmpdir/.step/config.json\"
  cp '$SCRIPT_DIR/scripts/step-core.js' \"\$tmpdir/scripts/step-core.js\"
  cp '$SCRIPT_DIR/scripts/step-pretool-guard.sh' \"\$tmpdir/scripts/step-pretool-guard.sh\"
  chmod +x \"\$tmpdir/scripts/step-core.js\" \"\$tmpdir/scripts/step-pretool-guard.sh\"
  node -e 'const fs=require(\"fs\");const sf=process.argv[1];const cf=process.argv[2];const s=JSON.parse(fs.readFileSync(sf,\"utf-8\"));s.current_phase=\"phase-4-execution\";s.session={mode:\"full\"};fs.writeFileSync(sf,JSON.stringify(s,null,2)+\"\\n\");const cfg=JSON.parse(fs.readFileSync(cf,\"utf-8\"));delete cfg.enforcement;fs.writeFileSync(cf,JSON.stringify(cfg,null,2)+\"\\n\")' \"\$tmpdir/.step/state.json\" \"\$tmpdir/.step/config.json\"
  cd \"\$tmpdir\"
  OPENCODE_TOOL_NAME=Write bash scripts/step-pretool-guard.sh
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]

# STEP scenario markers
