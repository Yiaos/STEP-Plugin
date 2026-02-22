#!/bin/bash
# T-035 测试：step-core 模块化核心能力

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

echo "=== T-035: step-core modules ==="

assert "[S-core-modules-01] parser handles chain split" node -e "
  const p = require('$SCRIPT_DIR/lib/core/command-parser')
  const got = p.splitChain('echo a && echo b; echo c || echo d')
  if (got.length !== 4) process.exit(1)
"

assert "[S-core-modules-02] parser resolves wrapped executable" node -e "
  const p = require('$SCRIPT_DIR/lib/core/command-parser')
  const got = p.executablesFromCommand(\"env bash -lc 'echo ok && rm -rf /tmp/x'\")
  if (!got.includes('bash') || !got.includes('rm')) process.exit(1)
"

assert "[S-core-modules-03] action guard detects dangerous" node -e "
  const g = require('$SCRIPT_DIR/lib/core/action-guard')
  const hit = g.firstDangerousExecutable(\"bash -lc 'rm -rf /tmp/x'\", ['rm'])
  if (hit !== 'rm') process.exit(1)
"

assert "[S-core-modules-04] state validator rejects invalid current_change" node -e "
  const v = require('$SCRIPT_DIR/lib/core/state-validator')
  const errs = v.validateState({
    project: 'x',
    current_phase: 'done',
    current_change: true,
    last_updated: '',
    last_agent: '',
    last_session_summary: '',
    session: { mode: 'full' },
    established_patterns: {},
    tasks: { current: null, upcoming: [] },
    key_decisions: [],
    known_issues: [],
    constraints_quick_ref: [],
    progress_log: [],
  })
  if (!errs.some((e) => e.includes('current_change'))) process.exit(1)
"

assert "[S-core-modules-05] phase policy transition and enforcement" node -e "
  const p = require('$SCRIPT_DIR/lib/core/phase-policy')
  if (!p.canTransition('phase-3-planning', 'phase-4-execution')) process.exit(1)
  if (p.canTransition('phase-1-prd', 'phase-4-execution')) process.exit(1)
  const lock = p.enforceWriteLockForMode({ enforcement: { planning_phase_write_lock: { full: true } } }, 'full')
  if (lock !== true) process.exit(1)
"

assert "[S-core-modules-06] phase policy exports path/config helpers" node -e "
  const p = require('$SCRIPT_DIR/lib/core/phase-policy')
  const obj = { a: { b: 1 } }
  if (p.getPathValue(obj, 'a.b') !== 1) process.exit(1)
  if (p.getConfigValue({ x: { y: true } }, 'x.y') !== true) process.exit(1)
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
