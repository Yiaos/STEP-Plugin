#!/bin/bash
# STEP Protocol — 卸载脚本
#
# 两种卸载模式：
#   bash uninstall.sh           # 卸载 opencode 插件
#   bash uninstall.sh --project # 清理当前项目的 .step/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
OPENCODE_PLUGIN_ROOT="${OPENCODE_PLUGIN_ROOT:-$HOME/.config/opencode/tools/step}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

uninstall_plugin() {
  echo -e "${YELLOW}🗑  Uninstalling STEP plugin from opencode...${NC}"

  TARGET_DIR="$OPENCODE_PLUGIN_ROOT"
  rm -f "${HOME}/.config/opencode/commands/step" && echo "  Removed commands symlink"
  rm -f "${HOME}/.config/opencode/skills/step"   && echo "  Removed skills symlink"
  rm -f "${HOME}/.config/opencode/plugins/step.js" && echo "  Removed plugin symlink"
  rm -f "${HOME}/.config/opencode/hooks/step"     && echo "  Removed hooks symlink"
  rm -f "${HOME}/.config/opencode/agents/step"    && echo "  Removed agents symlink"
  rm -rf "$TARGET_DIR"                            && echo "  Removed $TARGET_DIR"

  echo ""
  echo -e "${GREEN}✅ STEP plugin uninstalled from opencode${NC}"
  echo ""
  echo "Note: Project-level .step/ directories are NOT removed."
  echo "      Use 'bash uninstall.sh --project' inside a project to clean up."
}

uninstall_project() {
  if [ ! -d ".step" ]; then
    echo -e "${YELLOW}⚠️  No .step/ directory found in current directory.${NC}"
    exit 1
  fi

  echo -e "${YELLOW}🗑  Cleaning STEP files from current project...${NC}"

  rm -rf .step && echo "  Removed .step/"

  echo ""
  echo -e "${GREEN}✅ Project STEP files cleaned${NC}"
}

usage() {
  echo "STEP Protocol Uninstaller"
  echo ""
  echo "Usage:"
  echo "  bash uninstall.sh            Uninstall STEP plugin from opencode"
  echo "  bash uninstall.sh --project  Clean .step/ from current project"
  echo ""
}

case "${1:-}" in
  --help|-h)
    usage
    ;;
  --project)
    uninstall_project
    ;;
  "")
    uninstall_plugin
    ;;
  *)
    echo -e "${RED}Unknown option: $1${NC}"
    usage
    exit 1
    ;;
esac
