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

# [S-007-02] step-archive.sh 归档已完成变更
assert "[S-007-02] step-archive.sh 归档已完成变更" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p .step/changes/fix-bug/tasks .step/archive
  cat > .step/changes/fix-bug/tasks/fix-bug.md <<'TASK'
# fix-bug
\`\`\`json task
{
  "id": "fix-bug",
  "title": "fix bug",
  "mode": "lite",
  "status": "done",
  "scenarios": [],
  "done_when": []
}
\`\`\`
TASK
  bash '$SCRIPT_DIR/scripts/step-archive.sh' fix-bug 2>&1 | grep -q 'fix-bug'
  ls .step/archive/*fix-bug >/dev/null
  [ ! -d .step/changes/fix-bug ]
"

# [S-007-03] step-archive.sh 跳过未完成变更
assert "[S-007-03] step-archive.sh 跳过未完成变更" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p .step/changes/wip/tasks .step/archive
  cat > .step/changes/wip/tasks/wip-1.md <<'TASK1'
# wip-1
\`\`\`json task
{
  "id": "wip-1",
  "title": "wip 1",
  "mode": "lite",
  "status": "done",
  "scenarios": [],
  "done_when": []
}
\`\`\`
TASK1
  cat > .step/changes/wip/tasks/wip-2.md <<'TASK2'
# wip-2
\`\`\`json task
{
  "id": "wip-2",
  "title": "wip 2",
  "mode": "lite",
  "status": "in_progress",
  "scenarios": [],
  "done_when": []
}
\`\`\`
TASK2
  bash '$SCRIPT_DIR/scripts/step-archive.sh' wip 2>&1 | grep -q 'skipped'
  [ -d .step/changes/wip ]
"

# [S-007-04] step-archive.sh --all 批量归档变更
assert "[S-007-04] step-archive.sh --all 批量归档变更" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p .step/changes/change-a/tasks .step/changes/change-b/tasks .step/changes/change-c/tasks .step/archive
  cat > .step/changes/change-a/tasks/a.md <<'TA'
# a
\`\`\`json task
{\"id\":\"a\",\"title\":\"a\",\"mode\":\"lite\",\"status\":\"done\",\"scenarios\":[],\"done_when\":[]}
\`\`\`
TA
  cat > .step/changes/change-b/tasks/b.md <<'TB'
# b
\`\`\`json task
{\"id\":\"b\",\"title\":\"b\",\"mode\":\"lite\",\"status\":\"done\",\"scenarios\":[],\"done_when\":[]}
\`\`\`
TB
  cat > .step/changes/change-c/tasks/c.md <<'TC'
# c
\`\`\`json task
{\"id\":\"c\",\"title\":\"c\",\"mode\":\"lite\",\"status\":\"in_progress\",\"scenarios\":[],\"done_when\":[]}
\`\`\`
TC
  output=\$(bash '$SCRIPT_DIR/scripts/step-archive.sh' --all 2>&1)
  echo \"\$output\" | grep -q 'Archived: 2'
  ls .step/archive/*change-a >/dev/null
  ls .step/archive/*change-b >/dev/null
  [ -d .step/changes/change-c ]
"

# [S-007-05] step-archive.sh 处理不存在的变更
assert "[S-007-05] step-archive.sh 处理不存在的变更" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p .step/changes .step/archive
  bash '$SCRIPT_DIR/scripts/step-archive.sh' nonexistent 2>&1 | grep -q 'not found'
"

# [S-007-06] step-archive.sh 归档目录名带日期前缀
assert "[S-007-06] 归档目录名带 YYYY-MM-DD 日期前缀" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p .step/changes/dated-change/tasks .step/archive
  cat > .step/changes/dated-change/tasks/dated-task.md <<'TASK'
# dated-task
\`\`\`json task
{
  "id": "dated-task",
  "title": "dated task",
  "mode": "lite",
  "status": "done",
  "scenarios": [],
  "done_when": []
}
\`\`\`
TASK
  bash '$SCRIPT_DIR/scripts/step-archive.sh' dated-change >/dev/null 2>&1
  today=\$(date +%F)
  [ -d \".step/archive/\${today}-dated-change\" ]
"

# [S-007-07] 归档当前变更会清空 state.current_change
assert "[S-007-07] 归档当前变更会清空 current_change" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p .step/changes/init/tasks .step/archive
  cat > .step/changes/init/tasks/t1.md <<'TASK'
# t1
\`\`\`json task
{\"id\":\"t1\",\"title\":\"t1\",\"mode\":\"lite\",\"status\":\"done\",\"scenarios\":[],\"done_when\":[]}
\`\`\`
TASK
  cat > .step/state.json <<'INNER'
{\"project\":\"demo\",\"current_phase\":\"phase-4-execution\",\"current_change\":\"init\",\"last_updated\":\"2026-02-16\",\"last_agent\":\"tester\",\"last_session_summary\":\"\",\"session\":{\"mode\":\"full\"},\"established_patterns\":{},\"tasks\":{\"current\":\"t1\",\"upcoming\":[]},\"key_decisions\":[],\"known_issues\":[],\"constraints_quick_ref\":[],\"progress_log\":[]}
INNER
  bash '$SCRIPT_DIR/scripts/step-archive.sh' init >/dev/null 2>&1
  grep -q 'current_change' .step/state.json
  grep -q '""' .step/state.json
  grep -q 'current' .step/state.json
  grep -q 'null' .step/state.json
"

# ── /archive 命令测试 ──

# [S-007-08] archive.md 命令文件存在
assert "[S-007-08] archive.md 命令文件存在" bash -c "
  [ -f '$SCRIPT_DIR/commands/archive.md' ]
"

# [S-007-09] archive.md 包含正确的 frontmatter
assert "[S-007-09] archive.md 包含 description frontmatter" bash -c "
  head -3 '$SCRIPT_DIR/commands/archive.md' | grep -q 'description:'
"

# [S-007-10] archive.md 包含用法
assert "[S-007-10] archive.md 包含用法" bash -c "
  grep -q '/archive' '$SCRIPT_DIR/commands/archive.md'
  grep -q '/archive {change-name}' '$SCRIPT_DIR/commands/archive.md' || grep -q '/archive.*change' '$SCRIPT_DIR/commands/archive.md'
"

# ── WORKFLOW.md 归档相关 ──

# [S-007-11] WORKFLOW.md 包含归档触发方式
assert "[S-007-11] WORKFLOW.md 包含归档触发方式" bash -c "
  grep -q '归档触发方式' '$SCRIPT_DIR/WORKFLOW.md' || grep -q '触发方式' '$SCRIPT_DIR/WORKFLOW.md'
  grep -q '/archive' '$SCRIPT_DIR/WORKFLOW.md'
  grep -q 'step-archive.sh' '$SCRIPT_DIR/WORKFLOW.md'
"

# [S-007-12] WORKFLOW.md 归档提示规则
assert "[S-007-12] WORKFLOW.md 包含完成后提示归档" bash -c "
  grep -q '变更下所有 tasks 的 status 都为 done' '$SCRIPT_DIR/WORKFLOW.md' || grep -q '变更已完成' '$SCRIPT_DIR/WORKFLOW.md'
"

# [S-007-13] SKILL.md 包含归档规则
assert "[S-007-13] SKILL.md 包含归档规则" bash -c "
  grep -q '归档' '$SCRIPT_DIR/skills/step/SKILL.md'
  grep -q '/archive' '$SCRIPT_DIR/skills/step/SKILL.md'
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
