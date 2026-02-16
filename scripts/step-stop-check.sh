#!/bin/bash
# STEP Protocol — Stop Check Script
# 会话结束前检查 state.yaml 更新状态
# 输出: [STEP STOP CHECK] PASS / WARN / FAIL / SKIP

STATE_FILE=".step/state.yaml"

# 无 state.yaml → SKIP
if [ ! -f "$STATE_FILE" ]; then
  echo "[STEP STOP CHECK] SKIP: 无 $STATE_FILE"
  exit 0
fi

TODAY=$(date -u +%Y-%m-%d)
ISSUES=0

# 检查 last_updated 是否包含今天日期
if grep -m1 'last_updated:' "$STATE_FILE" 2>/dev/null | grep -q "$TODAY"; then
  UPDATED_OK=true
else
  UPDATED_OK=false
  ISSUES=$((ISSUES + 1))
  echo "[STEP STOP CHECK] WARN: last_updated 不包含今天 ($TODAY)"
fi

# 检查 progress_log 是否有今日条目
if grep -A1 'progress_log:' "$STATE_FILE" 2>/dev/null | grep -q "$TODAY" 2>/dev/null; then
  PROGRESS_OK=true
else
  # 更深层检查：在 progress_log 区域内搜索今天日期
  if sed -n '/^progress_log:/,/^[a-z]/p' "$STATE_FILE" 2>/dev/null | grep -q "$TODAY" 2>/dev/null; then
    PROGRESS_OK=true
  else
    PROGRESS_OK=false
    ISSUES=$((ISSUES + 1))
    echo "[STEP STOP CHECK] WARN: progress_log 无今日 ($TODAY) 条目"
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
  for task_file in "$tasks_dir"/*.yaml; do
    [ -f "$task_file" ] || continue
    found=1
    if ! grep -q '^status:[[:space:]]*done' "$task_file" 2>/dev/null; then
      all_done=false
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
  echo "[STEP STOP CHECK] PASS: state.yaml 已更新"
  exit 0
elif [ "$ISSUES" -ge 2 ]; then
  echo "[STEP STOP CHECK] FAIL: last_updated 和 progress_log 都需要更新"
  exit 0
else
  # 1 个 WARN 已经输出了
  exit 0
fi
