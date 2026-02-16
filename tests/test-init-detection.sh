#!/bin/bash
# T-003 测试：step-init.sh 检测逻辑增强
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

echo "=== T-003: step-init.sh 检测逻辑增强 ==="

# [S-003-01] 检测 STEP 类项目结构
assert "[S-003-01] 检测 STEP 类项目结构" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir -p scripts agents commands
  echo '#!/bin/bash' > scripts/test.sh
  echo '---' > agents/test.md
  echo '---' > commands/test.md
  eval \"\$(sed -n '/^detect_project()/,/^}/p' '$SCRIPT_DIR/scripts/step-init.sh')\"
  output=\$(detect_project)
  echo \"\$output\" | head -1 | grep -q 'existing'
"

# [S-003-02] 检测 Makefile/requirements.txt
assert "[S-003-02] 检测 Makefile/requirements.txt" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  touch Makefile requirements.txt
  eval \"\$(sed -n '/^detect_project()/,/^}/p' '$SCRIPT_DIR/scripts/step-init.sh')\"
  output=\$(detect_project)
  echo \"\$output\" | head -1 | grep -q 'existing'
"

# [S-003-03] 仅 .git 判定为 greenfield
assert "[S-003-03] 仅 .git 判定为 greenfield" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir .git
  eval \"\$(sed -n '/^detect_project()/,/^}/p' '$SCRIPT_DIR/scripts/step-init.sh')\"
  output=\$(detect_project)
  echo \"\$output\" | head -1 | grep -q 'greenfield'
"

# [S-003-04] 空目录不计入信号
assert "[S-003-04] 空目录不计入信号" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  mkdir scripts  # 空目录
  eval \"\$(sed -n '/^detect_project()/,/^}/p' '$SCRIPT_DIR/scripts/step-init.sh')\"
  output=\$(detect_project)
  echo \"\$output\" | head -1 | grep -q 'greenfield'
"

# [S-003-05] 空目录输出 greenfield
assert "[S-003-05] 空目录输出 greenfield" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  eval \"\$(sed -n '/^detect_project()/,/^}/p' '$SCRIPT_DIR/scripts/step-init.sh')\"
  output=\$(detect_project)
  echo \"\$output\" | head -1 | grep -q 'greenfield'
"

# [S-003-06] STEP 项目自身被正确识别
assert "[S-003-06] STEP 项目自身被正确识别" bash -c "
  set -e
  cd '$SCRIPT_DIR'
  eval \"\$(sed -n '/^detect_project()/,/^}/p' '$SCRIPT_DIR/scripts/step-init.sh')\"
  output=\$(detect_project)
  echo \"\$output\" | head -1 | grep -q 'existing'
"

# [S-003-07] 初始化会创建 init/spec.md 和 init/design.md
assert "[S-003-07] 初始化创建 spec.md 和 design.md" bash -c "
  set -e
  tmpdir=\$(mktemp -d)
  trap 'rm -rf \"\$tmpdir\"' EXIT
  cd \"\$tmpdir\"
  bash '$SCRIPT_DIR/scripts/step-init.sh' >/dev/null 2>&1
  [ -f .step/changes/init/spec.md ]
  [ -f .step/changes/init/design.md ]
"

echo ""
echo "=== 结果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
