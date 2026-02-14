#!/bin/bash
# STEP Protocol — 安装脚本
# 将 STEP 插件安装到 opencode 配置目录
#
# 用法:
#   bash install.sh          # 安装（已存在则跳过）
#   bash install.sh --force  # 强制覆盖安装
#   bash install.sh --uninstall  # 卸载

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
TARGET_DIR="${HOME}/.config/opencode/tools/step"
COMMANDS_LINK="${HOME}/.config/opencode/commands/step"
SKILLS_LINK="${HOME}/.config/opencode/skills/step"
HOOKS_LINK="${HOME}/.config/opencode/hooks/step"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
  echo "STEP Protocol Installer"
  echo ""
  echo "Usage:"
  echo "  bash install.sh            Install (skip if exists)"
  echo "  bash install.sh --force    Force reinstall"
  echo "  bash install.sh --uninstall  Remove STEP plugin"
  echo ""
}

uninstall() {
  echo -e "${YELLOW}🗑  Uninstalling STEP plugin...${NC}"
  rm -f "$COMMANDS_LINK" && echo "  Removed commands symlink"
  rm -f "$SKILLS_LINK" && echo "  Removed skills symlink"
  rm -f "$HOOKS_LINK" && echo "  Removed hooks symlink"
  rm -rf "$TARGET_DIR" && echo "  Removed $TARGET_DIR"
  echo -e "${GREEN}✅ STEP plugin uninstalled${NC}"
  echo ""
  echo "Note: Project-level .step/ directories are NOT removed."
  echo "      Remove them manually if needed: rm -rf /path/to/project/.step"
  exit 0
}

install() {
  local force=$1

  # 检查是否已安装
  if [ -d "$TARGET_DIR" ] && [ "$force" != "true" ]; then
    echo -e "${YELLOW}⚠️  STEP plugin already installed at $TARGET_DIR${NC}"
    echo "  Use --force to reinstall"
    exit 1
  fi

  echo -e "${GREEN}📦 Installing STEP plugin...${NC}"
  echo ""

  # 创建 opencode 目录（如果不存在）
  mkdir -p "${HOME}/.config/opencode/commands"
  mkdir -p "${HOME}/.config/opencode/skills"
  mkdir -p "${HOME}/.config/opencode/hooks"

  # 清理旧安装
  if [ -d "$TARGET_DIR" ]; then
    rm -rf "$TARGET_DIR"
    echo "  Cleaned previous installation"
  fi

  # 复制插件文件
  mkdir -p "$TARGET_DIR"
  cp -R "${SCRIPT_DIR}/commands" "$TARGET_DIR/"
  cp -R "${SCRIPT_DIR}/hooks" "$TARGET_DIR/"
  cp -R "${SCRIPT_DIR}/skills" "$TARGET_DIR/"
  cp -R "${SCRIPT_DIR}/scripts" "$TARGET_DIR/"
  cp -R "${SCRIPT_DIR}/templates" "$TARGET_DIR/"
  cp -R "${SCRIPT_DIR}/agents" "$TARGET_DIR/"
  [ -f "${SCRIPT_DIR}/WORKFLOW.md" ] && cp "${SCRIPT_DIR}/WORKFLOW.md" "$TARGET_DIR/"
  [ -f "${SCRIPT_DIR}/uninstall.sh" ] && cp "${SCRIPT_DIR}/uninstall.sh" "$TARGET_DIR/"
  echo "  Copied plugin files to $TARGET_DIR"

  # 设置权限
  chmod +x "$TARGET_DIR/hooks/session-start.sh"
  chmod +x "$TARGET_DIR/scripts/gate.sh"
  chmod +x "$TARGET_DIR/scripts/scenario-check.sh"
  chmod +x "$TARGET_DIR/scripts/step-init.sh"
  echo "  Set executable permissions"

  # 创建 symlinks
  ln -sfn "$TARGET_DIR/commands" "$COMMANDS_LINK"
  ln -sfn "$TARGET_DIR/skills" "$SKILLS_LINK"
  ln -sfn "$TARGET_DIR/hooks" "$HOOKS_LINK"
  echo "  Created symlinks"

  echo ""
  echo -e "${GREEN}✅ STEP plugin installed!${NC}"
  echo ""
  echo "  Plugin:   $TARGET_DIR"
  echo "  Commands: $COMMANDS_LINK → $TARGET_DIR/commands"
  echo "  Skills:   $SKILLS_LINK → $TARGET_DIR/skills"
  echo "  Hooks:    $HOOKS_LINK → $TARGET_DIR/hooks"
  echo ""
  echo "  Usage: In any project, run /step to initialize the STEP protocol."
  echo ""
  echo "  Plugin structure:"
  echo "  ~/.config/opencode/tools/step/"
  echo "  ├── commands/step.md        # /step command"
  echo "  ├── hooks/"
  echo "  │   ├── hooks.json          # SessionStart hook registration"
  echo "  │   └── session-start.sh    # Auto-detect .step/ and inject state"
  echo "  ├── skills/step/SKILL.md    # Core protocol rules"
  echo "  ├── scripts/"
  echo "  │   ├── step-init.sh        # Project initialization"
  echo "  │   ├── gate.sh             # Quality gate (quick/standard/full)"
  echo "  │   └── scenario-check.sh   # BDD scenario coverage check"
  echo "  ├── agents/                 # Role-based agent definitions"
  echo "  │   ├── pm.md               # Product Manager (Phase 0-1)"
  echo "  │   ├── architect.md        # Architect (Phase 2-3)"
  echo "  │   ├── qa.md               # QA Engineer (Phase 3/4/5)"
  echo "  │   └── developer.md        # Developer (Phase 4)"
  echo "  └── templates/              # Project file templates"
}

# 解析参数
case "${1:-}" in
  --help|-h)
    usage
    exit 0
    ;;
  --uninstall)
    uninstall
    ;;
  --force)
    install "true"
    ;;
  "")
    install "false"
    ;;
  *)
    echo -e "${RED}Unknown option: $1${NC}"
    usage
    exit 1
    ;;
esac
