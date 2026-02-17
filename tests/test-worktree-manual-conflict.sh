#!/bin/bash
# T-014 测试：worktree 不污染 git config，并对代码冲突转人工
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

echo "=== T-014: worktree 手工冲突策略与配置无污染 ==="

# [S-014-01] create 不写入 branch.*.step-base
assert "[S-014-01] create 不写 git config 自定义键" bash -c "
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
  cat > .step/config.json <<'CFG'
{
  "worktree": {
    "enabled": true,
    "branch_prefix": "change/"
  }
}
CFG
  printf 'v1\n' > a.txt
  git add .
  git commit -m 'init' >/dev/null 2>&1
  bash scripts/step-worktree.sh create x >/dev/null 2>&1
  ! git config --get-regexp 'branch\\..*\\.step-base' >/dev/null 2>&1
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
