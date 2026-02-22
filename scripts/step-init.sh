#!/bin/bash
# STEP Protocol — 项目初始化脚本
# 由 /step 命令调用，在当前项目创建 .step/ 目录

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEMPLATES_DIR="${PLUGIN_ROOT}/templates"
CORE_SCRIPT="${PLUGIN_ROOT}/scripts/step-core.js"
STEP_AGENTS_BEGIN="<!-- STEP:BEGIN DOC-ROLES -->"
STEP_AGENTS_END="<!-- STEP:END DOC-ROLES -->"

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

ensure_agents_step_guidance() {
  local agents_file="AGENTS.md"
  local guidance_content

  guidance_content=$(cat <<'EOF'
## STEP 文档职责（自动注入）

- `.step/baseline.md`: 需求与约束唯一事实源（SSOT）
- `.step/state.json`: 流程状态机唯一事实源（phase/change/task/next_action）
- `.step/changes/{change}/evidence/`: gate/review 证据
- `STEP 插件安装目录 scripts/`: 执行入口与硬约束脚本
- `AGENTS.md`: 仅导航，不复制 baseline 细则

### 冲突优先级
- 需求与范围冲突: 以 `.step/baseline.md` 为准
- 流程状态冲突: 以 `.step/state.json` 为准
- 执行与校验冲突: 以脚本运行结果为准
EOF
)

  printf '%s' "$guidance_content" | node "$CORE_SCRIPT" agents ensure-block \
    --file "$agents_file" \
    --begin "$STEP_AGENTS_BEGIN" \
    --end "$STEP_AGENTS_END" >/dev/null
}

# ── 主流程 ────────────────────────────────────────────────────

echo "📦 Initializing STEP protocol..."

# 检查是否已初始化
if [ -d ".step" ]; then
  echo "⚠️  .step/ already exists. Use /step to resume."
  exit 1
fi

# 检测项目类型
PROJECT_DETECT=$(detect_project)
PROJECT_TYPE=$(echo "$PROJECT_DETECT" | head -1)
PROJECT_DETAILS=$(echo "$PROJECT_DETECT" | tail -n +2)

# 创建目录结构
mkdir -p .step/changes/init/tasks .step/changes/init/evidence .step/archive

# 复制模板文件
cp "${TEMPLATES_DIR}/config.json" .step/config.json
cp "${TEMPLATES_DIR}/state.json" .step/state.json
cp "${TEMPLATES_DIR}/baseline.md" .step/baseline.md
cp "${TEMPLATES_DIR}/decisions.md" .step/decisions.md
cp "${TEMPLATES_DIR}/findings.md" .step/changes/init/findings.md
cp "${TEMPLATES_DIR}/spec.md" .step/changes/init/spec.md
cp "${TEMPLATES_DIR}/design.md" .step/changes/init/design.md

# 设置初始时间戳 + 项目类型
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
node "$CORE_SCRIPT" state set --file .step/state.json --path last_updated --value "$TIMESTAMP" >/dev/null
node "$CORE_SCRIPT" state set --file .step/state.json --path project_type --value "$PROJECT_TYPE" >/dev/null

ensure_agents_step_guidance

echo ""
echo "✅ STEP initialized!"
echo ""
echo "   .step/"
echo "   ├── config.json          # 模型路由 & gate 命令"
echo "   ├── baseline.md          # 需求基线（活快照）"
echo "   ├── decisions.md         # 架构决策日志"
echo "   ├── state.json           # 项目状态机"
echo "   ├── changes/"
echo "   │   └── init/            # 初始开发"
echo "   │       ├── findings.md  # 探索发现（Phase 0/2，可选）"
echo "   │       ├── spec.md      # 需求说明（Phase 1）"
echo "   │       ├── design.md    # 技术方案（Phase 2）"
echo "   │       ├── tasks/       # 任务 + BDD 场景（Phase 3）"
echo "   │       └── evidence/    # Gate/Review 证据（Phase 4/5）"
echo "   ├── archive/             # 已完成变更归档"
echo "   └── (无全局 evidence，证据按 change 存放)"
echo ""
echo "   STEP 执行脚本位于插件安装目录:"
echo "   ${PLUGIN_ROOT}/scripts/"
echo "   ├── gate.sh              # 质量门禁"
echo "   ├── scenario-check.sh    # 场景覆盖检查"
echo "   ├── step-worktree.sh     # worktree 创建/归档合并清理"
echo "   └── step-archive.sh      # 变更归档"
echo ""
echo "   AGENTS.md 已写入 STEP 文档职责导航"
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
  echo "   5. Set established_patterns in state.json based on findings"
  echo ""
  echo "   当前阶段: Phase 0 Discovery（已有项目模式）"
  echo "   请先分析现有代码，再描述新需求。"
else
  echo "   当前阶段: Phase 0 Discovery"
  echo "   请描述你的想法，我们开始讨论。"
fi
