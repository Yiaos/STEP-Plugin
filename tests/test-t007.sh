#!/bin/bash
# T-007 测试：归档功能 + /archive 命令
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

echo "=== T-007: 归档功能 + /archive 命令 ==="

# ── step-archive.sh 脚本测试 ──

# [S-007-01] step-archive.sh 存在且可执行
assert "[S-007-01] step-archive.sh 存在且可执行" bash -c "
  [ -x '$SCRIPT_DIR/scripts/step-archive.sh' ]
"

# [S-007-02] step-archive.sh 归档 done 状态任务
assert "[S-007-02] step-archive.sh 归档 done 状态任务" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p .step/tasks .step/archive
  printf 'id: fix-bug\nstatus: done\n' > .step/tasks/fix-bug.yaml
  bash '$SCRIPT_DIR/scripts/step-archive.sh' fix-bug 2>&1 | grep -q 'fix-bug'
  [ -f .step/archive/*fix-bug.yaml ]
  [ ! -f .step/tasks/fix-bug.yaml ]
"

# [S-007-03] step-archive.sh 跳过非 done 任务
assert "[S-007-03] step-archive.sh 跳过非 done 任务" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p .step/tasks .step/archive
  printf 'id: wip-task\nstatus: in_progress\n' > .step/tasks/wip-task.yaml
  bash '$SCRIPT_DIR/scripts/step-archive.sh' wip-task 2>&1 | grep -q 'skipped'
  [ -f .step/tasks/wip-task.yaml ]
"

# [S-007-04] step-archive.sh --all 批量归档
assert "[S-007-04] step-archive.sh --all 批量归档" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p .step/tasks .step/archive
  printf 'id: task-a\nstatus: done\n' > .step/tasks/task-a.yaml
  printf 'id: task-b\nstatus: done\n' > .step/tasks/task-b.yaml
  printf 'id: task-c\nstatus: in_progress\n' > .step/tasks/task-c.yaml
  output=\$(bash '$SCRIPT_DIR/scripts/step-archive.sh' --all 2>&1)
  echo \"\$output\" | grep -q 'Archived: 2'
  [ -f .step/archive/*task-a.yaml ]
  [ -f .step/archive/*task-b.yaml ]
  [ -f .step/tasks/task-c.yaml ]
"

# [S-007-05] step-archive.sh 处理不存在的 slug
assert "[S-007-05] step-archive.sh 处理不存在的 slug" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p .step/tasks .step/archive
  bash '$SCRIPT_DIR/scripts/step-archive.sh' nonexistent 2>&1 | grep -q 'not found'
"

# [S-007-06] step-archive.sh 归档文件名带日期前缀
assert "[S-007-06] 归档文件名带 YYYY-MM-DD 日期前缀" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p .step/tasks .step/archive
  printf 'id: dated-task\nstatus: done\n' > .step/tasks/dated-task.yaml
  bash '$SCRIPT_DIR/scripts/step-archive.sh' dated-task >/dev/null 2>&1
  today=\$(date +%F)
  [ -f \".step/archive/\${today}-dated-task.yaml\" ]
"

# ── /archive 命令测试 ──

# [S-007-07] archive.md 命令文件存在
assert "[S-007-07] archive.md 命令文件存在" bash -c "
  [ -f '$SCRIPT_DIR/commands/archive.md' ]
"

# [S-007-08] archive.md 包含正确的 frontmatter
assert "[S-007-08] archive.md 包含 description frontmatter" bash -c "
  head -3 '$SCRIPT_DIR/commands/archive.md' | grep -q 'description:'
"

# [S-007-09] archive.md 包含三种用法
assert "[S-007-09] archive.md 包含三种用法" bash -c "
  grep -q '/archive all' '$SCRIPT_DIR/commands/archive.md'
  grep -q '/archive.*slug' '$SCRIPT_DIR/commands/archive.md' || grep -q '/archive {slug}' '$SCRIPT_DIR/commands/archive.md'
"

# ── WORKFLOW.md 归档相关 ──

# [S-007-10] WORKFLOW.md 包含归档触发方式
assert "[S-007-10] WORKFLOW.md 包含归档触发方式" bash -c "
  grep -q '归档触发方式' '$SCRIPT_DIR/WORKFLOW.md' || grep -q '触发方式' '$SCRIPT_DIR/WORKFLOW.md'
  grep -q '/archive' '$SCRIPT_DIR/WORKFLOW.md'
  grep -q 'step-archive.sh' '$SCRIPT_DIR/WORKFLOW.md'
"

# [S-007-11] WORKFLOW.md 归档提示规则
assert "[S-007-11] WORKFLOW.md 包含完成后提示归档" bash -c "
  grep -q '所有任务.*完成' '$SCRIPT_DIR/WORKFLOW.md' || grep -q '任务.*done.*提示' '$SCRIPT_DIR/WORKFLOW.md'
"

# [S-007-12] SKILL.md 包含归档规则
assert "[S-007-12] SKILL.md 包含归档规则" bash -c "
  grep -q '归档' '$SCRIPT_DIR/skills/step/SKILL.md'
  grep -q '/archive' '$SCRIPT_DIR/skills/step/SKILL.md'
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
