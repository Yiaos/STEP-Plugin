#!/bin/bash
# T-034 测试：OpenCode plugin 注入与 SessionStart fallback

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

echo "=== T-034: plugin injection ==="

assert "[S-plugin-injection-01] step plugin syntax valid" bash -c "
  set -e
  node --check '$SCRIPT_DIR/.opencode/plugins/step.js'
"

assert "[S-plugin-injection-02] plugin injects STEP context when state exists" bash -c '
  set -e
  step_dir="$1"
  tmpdir=$(mktemp -d)
  trap "rm -rf \"$tmpdir\"" EXIT
  mkdir -p "$tmpdir/.step/changes/init"
  cat > "$tmpdir/.step/state.json" <<"STATE"
{"project":"demo","current_phase":"phase-4-execution","current_change":"init","last_updated":"2026-02-22T00:00:00Z","last_agent":"tester","last_session_summary":"","session":{"mode":"full"},"established_patterns":{},"tasks":{"current":null,"upcoming":[]},"key_decisions":[],"known_issues":[],"constraints_quick_ref":[],"progress_log":[]}
STATE
  cat > "$tmpdir/.step/changes/init/spec.md" <<"SPEC"
# Spec
SPEC
  cat > "$tmpdir/run-plugin.mjs" <<"JS"
import { pathToFileURL } from "url"

const pluginFile = process.argv[2]
const projectDir = process.argv[3]
const mod = await import(pathToFileURL(pluginFile).href)
if (typeof mod.StepPlugin !== "function") process.exit(2)
const plugin = await mod.StepPlugin({ directory: projectDir })
if (!plugin || typeof plugin["experimental.chat.system.transform"] !== "function") process.exit(3)
const output = { system: [] }
await plugin["experimental.chat.system.transform"]({}, output)
const merged = Array.isArray(output.system) ? output.system.join("\n") : ""
if (!merged.includes("<STEP_PROTOCOL>")) process.exit(4)
if (!merged.includes("STEP 协议已激活")) process.exit(5)
JS
  node "$tmpdir/run-plugin.mjs" "$step_dir/.opencode/plugins/step.js" "$tmpdir"
' _ "$SCRIPT_DIR"

assert "[S-plugin-injection-03] plugin no-op without state" bash -c '
  set -e
  step_dir="$1"
  tmpdir=$(mktemp -d)
  trap "rm -rf \"$tmpdir\"" EXIT
  cat > "$tmpdir/run-plugin-no-state.mjs" <<"JS"
import { pathToFileURL } from "url"

const pluginFile = process.argv[2]
const projectDir = process.argv[3]
const mod = await import(pathToFileURL(pluginFile).href)
const plugin = await mod.StepPlugin({ directory: projectDir })
const output = { system: [] }
await plugin["experimental.chat.system.transform"]({}, output)
if (Array.isArray(output.system) && output.system.length > 0) {
  process.exit(1)
}
JS
  node "$tmpdir/run-plugin-no-state.mjs" "$step_dir/.opencode/plugins/step.js" "$tmpdir"
' _ "$SCRIPT_DIR"

assert "[S-plugin-injection-04] session-start hook skips when plugin enabled" bash -c '
  set -e
  step_dir="$1"
  tmpdir=$(mktemp -d)
  trap "rm -rf \"$tmpdir\"" EXIT
  touch "$tmpdir/step.js"
  out=$(STEP_SESSIONSTART_SKIP_IF_PLUGIN=true OPENCODE_STEP_PLUGIN_FILE="$tmpdir/step.js" bash "$step_dir/hooks/session-start.sh")
  echo "$out" | grep -q "\"additionalContext\": \"\""
' _ "$SCRIPT_DIR"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
