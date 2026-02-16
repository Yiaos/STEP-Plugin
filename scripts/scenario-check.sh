#!/bin/bash
# STEP Scenario Coverage Check
# Usage: ./scripts/scenario-check.sh <task-slug> [change-name]
# 验证 task YAML 中每个场景 ID 都有对应的测试
# task-slug 即文件名（不含 .yaml），如: user-register-api

set -e

TASK_ID=${1:-""}
CHANGE_NAME=${2:-""}
if [ -z "$TASK_ID" ]; then
  echo "❌ Usage: scenario-check.sh <task-slug> [change-name]"
  echo "   Example: scenario-check.sh user-register-api"
  echo "   Example: scenario-check.sh user-register-api init"
  exit 1
fi

# 优先级: 显式 change 参数 > state.yaml current_change > 全局唯一匹配
TASK_FILE=""

if [ -n "$CHANGE_NAME" ]; then
  candidate=".step/changes/${CHANGE_NAME}/tasks/${TASK_ID}.yaml"
  if [ -f "$candidate" ]; then
    TASK_FILE="$candidate"
  else
    echo "❌ Not found: ${candidate}"
    exit 1
  fi
fi

if [ -z "$TASK_FILE" ] && [ -f ".step/state.yaml" ]; then
  CURRENT_CHANGE=$(grep '^current_change:' .step/state.yaml 2>/dev/null | head -1 | sed 's/^current_change:[[:space:]]*//' | tr -d ' "' || true)
  if [ -n "$CURRENT_CHANGE" ]; then
    candidate=".step/changes/${CURRENT_CHANGE}/tasks/${TASK_ID}.yaml"
    if [ -f "$candidate" ]; then
      TASK_FILE="$candidate"
      CHANGE_NAME="$CURRENT_CHANGE"
    fi
  fi
fi

if [ -z "$TASK_FILE" ]; then
  MATCHES=""
  for f in .step/changes/*/tasks/${TASK_ID}.yaml; do
    [ -f "$f" ] || continue
    MATCHES="${MATCHES} ${f}"
  done

  MATCH_COUNT=0
  for _m in $MATCHES; do
    MATCH_COUNT=$((MATCH_COUNT + 1))
  done

  if [ "$MATCH_COUNT" -eq 1 ]; then
    TASK_FILE=$(echo "$MATCHES" | sed 's/^ *//')
    CHANGE_NAME=$(echo "$TASK_FILE" | sed -E 's#^\.step/changes/([^/]+)/tasks/.*#\1#')
  elif [ "$MATCH_COUNT" -gt 1 ]; then
    echo "❌ Multiple matches found for task: ${TASK_ID}"
    echo "   Please specify change-name explicitly: scenario-check.sh ${TASK_ID} <change-name>"
    exit 1
  fi
fi

if [ -z "$TASK_FILE" ]; then
  echo "❌ Not found: .step/changes/*/tasks/${TASK_ID}.yaml"
  exit 1
fi

if [ -z "$CHANGE_NAME" ]; then
  CHANGE_NAME=$(echo "$TASK_FILE" | sed -E 's#^\.step/changes/([^/]+)/tasks/.*#\1#')
fi

echo "🔍 Checking scenario coverage for $TASK_ID (change: ${CHANGE_NAME})..."

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
  "change": "${CHANGE_NAME}",
  "task_file": "${TASK_FILE}",
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
