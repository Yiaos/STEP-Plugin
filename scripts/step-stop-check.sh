#!/bin/bash
# STEP Protocol — Stop Check Script
# 会话结束前检查 state.json 更新状态
# 输出: [STEP STOP CHECK] PASS / WARN / FAIL / SKIP

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CORE_SCRIPT="${SCRIPT_DIR}/step-core.js"
STATE_FILE=".step/state.json"
STRICT_MODE="${STEP_STOP_STRICT:-true}"

# 无 state.json → SKIP
if [ ! -f "$STATE_FILE" ]; then
  echo "[STEP STOP CHECK] SKIP: 无 $STATE_FILE"
  exit 0
fi

state_get() {
  local dot_path="$1"
  node "$CORE_SCRIPT" state get --file "$STATE_FILE" --path "$dot_path" 2>/dev/null || true
}

task_status_is() {
  local task_file="$1"
  local expected="$2"
  node "$CORE_SCRIPT" task status --file "$task_file" --expected "$expected" >/dev/null 2>&1
}

TODAY=$(date -u +%Y-%m-%d)
ISSUES=0

# 检查 last_updated 是否包含今天日期
LAST_UPDATED="$(state_get "last_updated")"
if [[ "$LAST_UPDATED" == *"$TODAY"* ]]; then
  UPDATED_OK=true
else
  UPDATED_OK=false
  ISSUES=$((ISSUES + 1))
  echo "[STEP STOP CHECK] WARN: last_updated 不包含今天 ($TODAY)"
fi

# 检查 progress_log 是否有今日条目
if node "$CORE_SCRIPT" state has-progress --file "$STATE_FILE" --date "$TODAY" >/dev/null 2>&1; then
  PROGRESS_OK=true
else
  PROGRESS_OK=false
  ISSUES=$((ISSUES + 1))
  echo "[STEP STOP CHECK] WARN: progress_log 无今日 ($TODAY) 条目"
fi

# 失败记录约束：gate 失败时必须立即记录可执行 next_action，且 next_action 不能等于 failed_action
if node "$CORE_SCRIPT" state validate-failure-log --file "$STATE_FILE" --date "$TODAY" >/dev/null 2>&1; then
  :
else
  rc=$?
  ISSUES=$((ISSUES + 1))
  if [ "$rc" -eq 2 ]; then
    echo "[STEP STOP CHECK] WARN: gate 失败后缺少 next_action"
  elif [ "$rc" -eq 3 ]; then
    echo "[STEP STOP CHECK] WARN: next_action 不得与 failed_action 相同"
  else
    echo "[STEP STOP CHECK] WARN: 失败记录检查异常"
  fi
fi

# findings 更新频率检查（2-Action Rule 分级阈值）
PHASE="$(state_get "current_phase")"
FINDINGS_ACTIONS_RAW="$(state_get "session.findings_actions")"
FINDINGS_UPDATED_RAW="$(state_get "session.findings_updated")"
FINDINGS_THRESHOLD=2
case "$PHASE" in
  phase-0-discovery|lite-l1-quick-spec)
    FINDINGS_THRESHOLD=2
    ;;
  phase-1-prd|phase-2-tech-design|phase-3-planning)
    FINDINGS_THRESHOLD=3
    ;;
  phase-4-execution|phase-5-review|lite-l2-execution|lite-l3-review)
    FINDINGS_THRESHOLD=4
    ;;
  idle|done)
    FINDINGS_THRESHOLD=0
    ;;
  *)
    FINDINGS_THRESHOLD=2
    ;;
esac

if [ "$FINDINGS_THRESHOLD" -gt 0 ] && [[ "$FINDINGS_ACTIONS_RAW" =~ ^[0-9]+$ ]]; then
  if [ "$FINDINGS_ACTIONS_RAW" -ge "$FINDINGS_THRESHOLD" ] && [ "$FINDINGS_UPDATED_RAW" != "true" ]; then
    ISSUES=$((ISSUES + 1))
    echo "[STEP STOP CHECK] WARN: findings 更新不足（phase=$PHASE, actions=$FINDINGS_ACTIONS_RAW, threshold=$FINDINGS_THRESHOLD）"
  fi
fi

# 检查是否有可归档的变更（变更下所有任务都 done）
ARCHIVE_COUNT=0
for change_dir in .step/changes/*; do
  [ -d "$change_dir" ] || continue
  tasks_dir="$change_dir/tasks"
  [ -d "$tasks_dir" ] || continue

  found=0
  all_done=true
  for task_file in "$tasks_dir"/*.md; do
    [ -f "$task_file" ] || continue
    found=1
    if ! task_status_is "$task_file" "done"; then
      all_done=false
      break
    fi
    task_slug="$(basename "$task_file" .md)"
    change_name="$(basename "$change_dir")"
    if ! node "$CORE_SCRIPT" task ready --task "$task_slug" --change "$change_name" >/dev/null 2>&1; then
      all_done=false
      ISSUES=$((ISSUES + 1))
      echo "[STEP STOP CHECK] WARN: $change_name/$task_slug 标记为 done，但场景状态未完成（存在 not_run/fail）"
      break
    fi
  done

  if [ "$found" -eq 1 ] && [ "$all_done" = true ]; then
    ARCHIVE_COUNT=$((ARCHIVE_COUNT + 1))
  fi
done

if [ "$ARCHIVE_COUNT" -gt 0 ]; then
  echo "[STEP STOP CHECK] REMIND: ${ARCHIVE_COUNT} 个变更可归档（/archive 或 /archive {change-name}）"
fi

# 综合判定
if [ "$ISSUES" -eq 0 ]; then
  echo "[STEP STOP CHECK] PASS: state.json 已更新"
  exit 0
else
  if [ "$STRICT_MODE" = "true" ]; then
    if [ "$ISSUES" -ge 2 ]; then
      echo "[STEP STOP CHECK] FAIL: last_updated 和 progress_log 都需要更新"
    else
      echo "[STEP STOP CHECK] FAIL(strict): 检测到 1 个未更新项"
    fi
    exit 1
  fi
  # 非严格模式：保留 WARN，不阻断结束
  exit 0
fi
