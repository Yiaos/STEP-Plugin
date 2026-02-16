#!/bin/bash
# T-010 测试：worktree 模式配置与脚本行为
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

echo "=== T-010: worktree 模式配置与脚本行为 ==="

# [S-010-01] templates/config.yaml 包含 worktree 配置项
assert "[S-010-01] config 模板包含 worktree 字段" bash -c "
  set -e
  grep -q '^worktree:' '$SCRIPT_DIR/templates/config.yaml'
  grep -q 'enabled:' '$SCRIPT_DIR/templates/config.yaml'
  grep -q 'branch_prefix:' '$SCRIPT_DIR/templates/config.yaml'
  ! grep -q 'base_branch:' '$SCRIPT_DIR/templates/config.yaml'
  ! grep -q 'auto_create:' '$SCRIPT_DIR/templates/config.yaml'
  ! grep -q 'ask_archive_and_merge_after_commit:' '$SCRIPT_DIR/templates/config.yaml'
"

# [S-010-02] 文档包含 worktree 自动流程说明
assert "[S-010-02] WORKFLOW/SKILL 包含 worktree 流程" bash -c "
  set -e
  grep -q 'Worktree 自动流程' '$SCRIPT_DIR/WORKFLOW.md'
  grep -q 'step-worktree.sh create' '$SCRIPT_DIR/skills/step/SKILL.md'
  grep -q 'step-worktree.sh finalize' '$SCRIPT_DIR/skills/step/SKILL.md'
"

# [S-010-03] step-worktree.sh 可创建并清理 worktree，冲突时输出解决策略
assert "[S-010-03] step-worktree 创建/合并/冲突报告/清理" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"

  git init -b main >/dev/null 2>&1
  git config user.email 'test@example.com'
  git config user.name 'STEP Test'

  mkdir -p .step scripts
  cp '$SCRIPT_DIR/scripts/step-worktree.sh' scripts/step-worktree.sh
  chmod +x scripts/step-worktree.sh

  cat > .step/config.yaml <<'CFG'
worktree:
  enabled: true
  branch_prefix: "change/"
CFG

  printf 'main-v1\n' > app.txt
  git add .
  git commit -m 'init' >/dev/null 2>&1

  bash scripts/step-worktree.sh create demo-change >/dev/null 2>&1
  [ -d .worktrees/demo-change ]

  printf 'feature-v1\n' > .worktrees/demo-change/app.txt
  git -C .worktrees/demo-change add app.txt
  git -C .worktrees/demo-change commit -m 'feature change' >/dev/null 2>&1

  printf 'main-v2\n' > app.txt
  git add app.txt
  git commit -m 'main change' >/dev/null 2>&1

  output=\$(bash scripts/step-worktree.sh finalize demo-change --yes 2>&1)
  echo \"\$output\" | grep -q 'Merge conflicts detected'
  echo \"\$output\" | grep -q 'app.txt'
  echo \"\$output\" | grep -q "used 'ours'"

  grep -q '^main-v2$' app.txt
  [ ! -d .worktrees/demo-change ]
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
