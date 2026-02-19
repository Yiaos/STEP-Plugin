#!/bin/bash
# STEP 安装健康检查脚本

set -u

TOOLS_DIR="${HOME}/.config/opencode/tools/step"
INSTALL_SCRIPT="${TOOLS_DIR}/install.sh"

COMMANDS_LINK="${HOME}/.config/opencode/commands/step"
SKILLS_LINK="${HOME}/.config/opencode/skills/step"
HOOKS_LINK="${HOME}/.config/opencode/hooks/step"
AGENTS_LINK="${HOME}/.config/opencode/agents/step"

STATUS=0

pass() {
  echo "PASS: $1"
}

fail() {
  echo "FAIL: $1"
  STATUS=1
}

check_symlink() {
  local link_path="$1"
  local expected_target="$2"
  local label="$3"
  local actual_target

  if [ ! -L "$link_path" ]; then
    fail "$label 链接缺失: $link_path"
    return
  fi

  actual_target="$(readlink "$link_path" 2>/dev/null || true)"
  if [ "$actual_target" != "$expected_target" ]; then
    fail "$label 链接指向错误: $link_path -> $actual_target (期望: $expected_target)"
    return
  fi

  pass "$label 链接正常: $link_path -> $actual_target"
}

echo "=== STEP Doctor ==="

if [ -d "$TOOLS_DIR" ]; then
  pass "STEP 工具目录存在: $TOOLS_DIR"
else
  fail "STEP 工具目录不存在: $TOOLS_DIR"
fi

check_symlink "$COMMANDS_LINK" "$TOOLS_DIR/commands" "commands"
check_symlink "$SKILLS_LINK" "$TOOLS_DIR/skills" "skills"
check_symlink "$HOOKS_LINK" "$TOOLS_DIR/hooks" "hooks"
check_symlink "$AGENTS_LINK" "$TOOLS_DIR/agents" "agents"

AGENTS_DIR="$TOOLS_DIR/agents"
for role in pm architect qa developer designer reviewer deployer; do
  if [ -f "$AGENTS_DIR/$role.md" ]; then
    pass "角色文件存在: $AGENTS_DIR/$role.md"
  else
    fail "缺少角色文件: $AGENTS_DIR/$role.md"
  fi
done

echo ""
if [ "$STATUS" -eq 0 ]; then
  echo "STEP Doctor 结果: PASS"
  exit 0
fi

echo "STEP Doctor 结果: FAIL"
if [ -f "$INSTALL_SCRIPT" ]; then
  echo "修复建议: bash ~/.config/opencode/tools/step/install.sh --force"
else
  echo "修复建议: 在 STEP 仓库根目录执行 bash install.sh --force"
fi
exit 1
