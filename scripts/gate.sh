#!/bin/bash
# STEP Gate — 质量门禁
# Usage: ./scripts/gate.sh [quick|lite|standard|full] [TASK_ID]
#   quick    — lint + typecheck only
#   lite     — lint + typecheck + test + scenario coverage (no build)
#   standard — lint + typecheck + test + scenario coverage (default)
#   full     — standard + build

set -e

LEVEL=${1:-standard}
TASK_ID=${2:-""}
PASS=true
RESULTS=""

run_check() {
  local name=$1; local cmd=$2
  echo "--- $name ---"
  if eval "$cmd" 2>&1; then
    echo "  ✅ $name: PASS"
    RESULTS="${RESULTS}{\"name\":\"$name\",\"status\":\"pass\"},"
  else
    echo "  ❌ $name: FAIL"
    RESULTS="${RESULTS}{\"name\":\"$name\",\"status\":\"fail\"},"
    PASS=false
  fi
}

echo "🚧 Gate (level: $LEVEL, task: ${TASK_ID:-all})"
echo ""

# 读取 gate 命令配置（如果 config.yaml 存在）
LINT_CMD="pnpm lint --no-error-on-unmatched-pattern"
TC_CMD="pnpm tsc --noEmit"
TEST_CMD="pnpm vitest run"
BUILD_CMD="pnpm build"

if [ -f ".step/config.yaml" ]; then
  _lint=$(grep "lint:" .step/config.yaml 2>/dev/null | head -1 | sed 's/.*lint: *//' | tr -d '"' || true)
  _tc=$(grep "typecheck:" .step/config.yaml 2>/dev/null | head -1 | sed 's/.*typecheck: *//' | tr -d '"' || true)
  _test=$(grep "test:" .step/config.yaml 2>/dev/null | head -1 | sed 's/.*test: *//' | tr -d '"' || true)
  _build=$(grep "build:" .step/config.yaml 2>/dev/null | head -1 | sed 's/.*build: *//' | tr -d '"' || true)
  [ -n "$_lint" ] && LINT_CMD="$_lint"
  [ -n "$_tc" ] && TC_CMD="$_tc"
  [ -n "$_test" ] && TEST_CMD="$_test"
  [ -n "$_build" ] && BUILD_CMD="$_build"
fi

# Always run: lint + typecheck
run_check "lint" "$LINT_CMD"
run_check "typecheck" "$TC_CMD"

# lite/standard/full: run tests
if [ "$LEVEL" != "quick" ]; then
  run_check "test" "$TEST_CMD"
fi

# lite/standard/full: scenario coverage check (if task specified)
if [ "$LEVEL" != "quick" ] && [ -n "$TASK_ID" ]; then
  SCENARIO_SCRIPT="./scripts/scenario-check.sh"
  if [ -f "$SCENARIO_SCRIPT" ]; then
    run_check "scenario-coverage" "$SCENARIO_SCRIPT $TASK_ID"
  else
    echo "⚠️  scenario-check.sh not found, skipping scenario coverage"
  fi
fi

# full only: run build (lite explicitly skips build)
if [ "$LEVEL" = "full" ]; then
  run_check "build" "$BUILD_CMD"
fi

echo ""

# Save evidence if task specified
if [ -n "$TASK_ID" ]; then
  mkdir -p .step/evidence
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  cat > ".step/evidence/${TASK_ID}-gate.json" <<EVIDENCE
{
  "task_id": "${TASK_ID}",
  "level": "${LEVEL}",
  "timestamp": "${TIMESTAMP}",
  "passed": ${PASS},
  "results": [${RESULTS%,}]
}
EVIDENCE
  echo "📄 Evidence saved: .step/evidence/${TASK_ID}-gate.json"
fi

if [ "$PASS" = true ]; then
  echo "✅ Gate PASSED"
  exit 0
else
  echo "❌ Gate FAILED"
  exit 1
fi
