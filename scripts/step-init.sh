#!/bin/bash
# STEP Protocol — 项目初始化脚本
# 由 /step/init 命令调用，在当前项目创建 .step/ 目录和 scripts/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEMPLATES_DIR="${PLUGIN_ROOT}/templates"

# ── 已有项目检测 ──────────────────────────────────────────────

detect_project() {
  local signals=0
  local manifests=""
  local src_dirs=""
  local test_dirs=""
  local has_git="false"

  # 包管理器 / 项目清单
  for f in package.json Cargo.toml go.mod pyproject.toml Gemfile \
           build.gradle pom.xml composer.json pubspec.yaml \
           Makefile CMakeLists.txt requirements.txt setup.py setup.cfg \
           deno.json bun.lockb mix.exs; do
    if [ -f "$f" ]; then
      signals=$((signals + 1))
      manifests="${manifests}   📄 ${f}\n"
    fi
  done

  # 源码目录
  for d in src lib app components pages api cmd pkg internal \
           scripts agents commands hooks templates skills; do
    if [ -d "$d" ]; then
      local count
      count=$(find "$d" -type f 2>/dev/null | wc -l | tr -d ' ')
      if [ "$count" -gt 0 ]; then
        signals=$((signals + 1))
        src_dirs="${src_dirs}   📁 ${d}/ (${count} files)\n"
      fi
    fi
  done

  # 测试目录
  for d in tests test __tests__ spec e2e cypress; do
    if [ -d "$d" ]; then
      local count
      count=$(find "$d" -type f 2>/dev/null | wc -l | tr -d ' ')
      if [ "$count" -gt 0 ]; then
        test_dirs="${test_dirs}   🧪 ${d}/ (${count} files)\n"
      fi
    fi
  done

  # Git
  if [ -d ".git" ]; then
    has_git="true"
  fi

  # 输出
  if [ "$signals" -gt 0 ]; then
    echo "existing"
    echo -e "${manifests}${src_dirs}${test_dirs}" | sed '/^$/d'
    if [ "$has_git" = "true" ]; then
      echo "   🔀 git repository"
    fi
  else
    echo "greenfield"
  fi
}

# ── 主流程 ────────────────────────────────────────────────────

echo "📦 Initializing STEP protocol..."

# 检查是否已初始化
if [ -d ".step" ]; then
  echo "⚠️  .step/ already exists. Use /step/init to resume."
  exit 1
fi

# 检测项目类型
PROJECT_DETECT=$(detect_project)
PROJECT_TYPE=$(echo "$PROJECT_DETECT" | head -1)
PROJECT_DETAILS=$(echo "$PROJECT_DETECT" | tail -n +2)

# 创建目录结构
mkdir -p .step/changes/init/tasks .step/evidence .step/archive scripts

# 复制模板文件
cp "${TEMPLATES_DIR}/config.yaml" .step/config.yaml
cp "${TEMPLATES_DIR}/state.yaml" .step/state.yaml
cp "${TEMPLATES_DIR}/baseline.md" .step/baseline.md
cp "${TEMPLATES_DIR}/decisions.md" .step/decisions.md
cp "${TEMPLATES_DIR}/findings.md" .step/changes/init/findings.md
cp "${TEMPLATES_DIR}/spec.md" .step/changes/init/spec.md
cp "${TEMPLATES_DIR}/design.md" .step/changes/init/design.md

# 复制 gate 脚本（如果 scripts/ 下没有的话）
if [ ! -f "scripts/gate.sh" ]; then
  cp "${PLUGIN_ROOT}/scripts/gate.sh" scripts/gate.sh
  chmod +x scripts/gate.sh
fi

if [ ! -f "scripts/scenario-check.sh" ]; then
  cp "${PLUGIN_ROOT}/scripts/scenario-check.sh" scripts/scenario-check.sh
  chmod +x scripts/scenario-check.sh
fi

if [ ! -f "scripts/step-worktree.sh" ]; then
  cp "${PLUGIN_ROOT}/scripts/step-worktree.sh" scripts/step-worktree.sh
  chmod +x scripts/step-worktree.sh
fi

# 设置初始时间戳 + 项目类型
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
if command -v sed &>/dev/null; then
  sed -i.bak "s/last_updated: \"\"/last_updated: \"${TIMESTAMP}\"/" .step/state.yaml
  # 在 project 行后插入 project_type
  sed -i.bak "/^project:/a\\
project_type: \"${PROJECT_TYPE}\"" .step/state.yaml
  rm -f .step/state.yaml.bak
fi

echo ""
echo "✅ STEP initialized!"
echo ""
echo "   .step/"
echo "   ├── config.yaml          # 模型路由 & gate 命令"
echo "   ├── baseline.md          # 需求基线（活快照）"
echo "   ├── decisions.md         # 架构决策日志"
echo "   ├── state.yaml           # 项目状态机"
echo "   ├── changes/"
echo "   │   └── init/            # 初始开发"
echo "   │       ├── findings.md  # 探索发现（Phase 0/2，可选）"
echo "   │       ├── spec.md      # 需求说明（Phase 1）"
echo "   │       ├── design.md    # 技术方案（Phase 2）"
echo "   │       └── tasks/       # 任务 + BDD 场景（Phase 3）"
echo "   ├── archive/             # 已完成变更归档"
echo "   └── evidence/            # gate 运行证据"
echo ""
echo "   scripts/"
echo "   ├── gate.sh              # 质量门禁"
echo "   ├── scenario-check.sh    # 场景覆盖检查"
echo "   └── step-worktree.sh     # worktree 创建/归档合并清理"
echo ""

# ── 已有项目提示 ──────────────────────────────────────────────

if [ "$PROJECT_TYPE" = "existing" ]; then
  echo "   ⚠️  检测到已有项目代码："
  echo -e "$PROJECT_DETAILS"
  echo ""
  echo "   [EXISTING PROJECT — LLM INSTRUCTIONS]"
  echo "   This is an existing codebase. Phase 0 Discovery should additionally:"
  echo "   1. Analyze existing code structure, frameworks, and conventions"
  echo "   2. Identify established patterns (naming, architecture, test strategy)"
  echo "   3. Review existing tests — what coverage exists, what's missing"
  echo "   4. Populate .step/baseline.md with existing project context BEFORE"
  echo "      discussing new requirements on top of it"
  echo "   5. Set established_patterns in state.yaml based on findings"
  echo ""
  echo "   当前阶段: Phase 0 Discovery（已有项目模式）"
  echo "   请先分析现有代码，再描述新需求。"
else
  echo "   当前阶段: Phase 0 Discovery"
  echo "   请描述你的想法，我们开始讨论。"
fi
