#!/bin/bash
# STEP Scenario Coverage Check
# Usage: ./scripts/scenario-check.sh TASK_ID
# 验证 task YAML 中每个场景 ID 都有对应的测试

set -e

TASK_ID=$1
if [ -z "$TASK_ID" ]; then
  echo "❌ Usage: scenario-check.sh TASK_ID"
  exit 1
fi

TASK_FILE=".step/tasks/${TASK_ID}.yaml"
if [ ! -f "$TASK_FILE" ]; then
  echo "❌ Not found: $TASK_FILE"
  exit 1
fi

echo "🔍 Checking scenario coverage for $TASK_ID..."

TOTAL=0
COVERED=0
MISSING=""
CURRENT_SID=""

while IFS= read -r line; do
  # 匹配场景 ID 行
  if echo "$line" | grep -qE "^\s+- id: S-"; then
    CURRENT_SID=$(echo "$line" | sed 's/.*id: *//' | tr -d ' ')
    TOTAL=$((TOTAL + 1))
  fi

  # 匹配 test_file 行，检查该文件中是否包含场景 ID
  if echo "$line" | grep -q "test_file:" && [ -n "$CURRENT_SID" ]; then
    TF=$(echo "$line" | sed 's/.*test_file: *//' | tr -d '"'"'" | tr -d ' ')
    if [ -f "$TF" ] && grep -q "\[${CURRENT_SID}\]" "$TF"; then
      COVERED=$((COVERED + 1))
    else
      MISSING="${MISSING}\n  ❌ ${CURRENT_SID} not found in ${TF}"
    fi
    CURRENT_SID=""
  fi
done < "$TASK_FILE"

# 计算覆盖率
if [ $TOTAL -gt 0 ]; then
  COV=$((COVERED * 100 / TOTAL))
else
  COV=0
fi

echo "📊 Coverage: ${COVERED}/${TOTAL} (${COV}%)"

# 保存 evidence
if [ -n "$TASK_ID" ]; then
  mkdir -p .step/evidence
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  cat > ".step/evidence/${TASK_ID}-scenario.json" <<EVIDENCE
{
  "task_id": "${TASK_ID}",
  "timestamp": "${TIMESTAMP}",
  "total": ${TOTAL},
  "covered": ${COVERED},
  "coverage_pct": ${COV},
  "passed": $([ $COV -eq 100 ] && echo "true" || echo "false")
}
EVIDENCE
fi

if [ -n "$MISSING" ]; then
  echo -e "\nMissing:${MISSING}"
fi

if [ $COV -eq 100 ]; then
  echo "✅ Scenario coverage PASS"
  exit 0
else
  echo "❌ Scenario coverage FAIL (need 100%)"
  exit 1
fi
