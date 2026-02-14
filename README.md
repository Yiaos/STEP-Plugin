# STEP（Stateful Task Execution Protocol）

STEP 是一个 opencode 插件，为 AI 编码代理提供全生命周期开发协议。它通过状态机、硬性门禁和 Session 恢复机制，把“看似完成”的工作变成“可验证完成”。

## 1. 为什么做 STEP（Problem Statement）

在使用 LLM 编码代理（opencode、codex、claude code）时，存在两个核心痛点：

1. **任务完成度不足**：MVP 任务看起来“完成了”但实际有 bug 和缺失场景。即使要求 BDD/TDD，agent 也经常跳过边界情况、错误处理。缺乏硬性门禁机制来阻止“假完成”。
2. **跨 Session 上下文丢失**：中断后恢复工作时，背景丢失，需要重新解释。新 session 的方案可能与之前冲突。现有工具（planning-with-files, openspec）记录计划但不强制执行约束。

缺失的关键能力是：**任务状态机 + 硬性质量门禁 + Session 恢复协议 + 需求漂移防护**，并通过 hooks 强制执行（不仅仅是 prompt）。

## 2. STEP 解决什么问题（What STEP Does）

STEP 提供 6 阶段生命周期：

| Phase | 名称 | 目标 |
| --- | --- | --- |
| 0 | Discovery | 开放式讨论，澄清问题与目标 |
| 1 | PRD | 选择题确认，冻结 baseline |
| 2 | Tech Design | 开放式讨论，锁定 ADR |
| 3 | Plan & Tasks | BDD 场景矩阵 |
| 4 | Execution | TDD + Gate 质量门禁 |
| 5 | Review | 需求合规 > 代码质量 |

关键机制：

- BDD 场景矩阵：每个场景有 ID，测试名必须包含 ID，100% 覆盖才能通过
- Gate 门禁：lint + typecheck + test + scenario coverage
- SessionStart Hook 自动恢复状态
- baseline 冻结 + Change Request 防漂移
- Post-MVP 流程（CR、Hotfix、约束变更）同样遵循 STEP

## 3. 安装（Installation）

```bash
# 安装
bash install.sh

# 强制覆盖安装
bash install.sh --force

# 卸载插件
bash uninstall.sh

# 清理当前项目的 .step/ 文件
bash uninstall.sh --project
```

安装后的目录结构：

```
~/.config/opencode/tools/step/
├── commands/step.md        # /step 命令
├── hooks/
│   ├── hooks.json          # SessionStart hook
│   └── session-start.sh    # 自动检测 .step/ 并注入状态
├── skills/step/SKILL.md    # 核心协议规则
├── scripts/
│   ├── step-init.sh        # 项目初始化
│   ├── gate.sh             # 质量门禁 (quick/standard/full)
│   └── scenario-check.sh   # BDD 场景覆盖检查
├── agents/                 # 角色 agent 定义
│   ├── pm.md               # 产品经理 (Phase 0-1)
│   ├── architect.md        # 架构师 (Phase 2-3)
│   ├── qa.md               # 质量工程师 (Phase 3/4/5)
│   └── developer.md        # 开发者 (Phase 4)
└── templates/              # 项目文件模板
```

### 角色系统

STEP 定义 4 个角色，每个角色对应一个 agent 定义（`agents/*.md`），在对应阶段使用不同模型和思维模式：

| 角色 | 阶段 | 思维模式 |
| --- | --- | --- |
| PM | Phase 0-1 | 用户视角、需求优先级、验收标准 |
| Architect | Phase 2-3 | 技术权衡、系统设计、任务拆分 |
| QA | Phase 3/4/5 | 对抗性测试思维、根因分析、需求合规 |
| Developer | Phase 4 | TDD 实现、遵循 patterns、不越界 |

角色之间形成制衡：PM 定义"做什么"、Architect 定义"怎么做"、QA 定义"怎么破坏它"、Developer 只做被定义的事。

## 4. 使用（Usage）

```
# 在任何项目中启动 STEP
/step

# 新项目 → 自动初始化 .step/ 目录 → 进入 Phase 0
# 已有项目 → 自动恢复到上次中断的阶段和任务
```

## 5. 项目文件结构（Project Files）

`/step` 会在项目中创建：

```
.step/
├── config.yaml          # 模型路由 & gate 命令（可自定义）
├── baseline.md          # 需求基线（Phase 1 冻结）
├── decisions.md         # 架构决策日志
├── state.yaml           # 项目状态机（Session 恢复核心）
├── tasks/               # 任务定义 + BDD 场景矩阵
├── change-requests/     # 变更请求
└── evidence/            # gate 运行证据
scripts/
├── gate.sh              # 质量门禁
└── scenario-check.sh    # 场景覆盖检查
```

## 6. 配置（Configuration）

`.step/config.yaml` 控制模型路由与 gate 命令，所有模型与命令均可自定义。示例：

```yaml
model_routing:
  # 规划阶段
  discovery: { model: "claude-opus" }
  prd: { model: "claude-opus" }
  tech_design: { model: "claude-opus" }
  planning: { model: "claude-opus" }

  # 执行阶段（均可按项目需求修改）
  test_writing: { model: "codex", note: "建议与实现模型不同以形成对抗性" }
  frontend: { model: "gemini", patterns: ["src/components/**", "**/*.tsx"] }
  backend: { model: "codex", patterns: ["src/api/**", "src/lib/**"] }
  complex_logic: { model: "claude-opus" }

  # 审查阶段
  review: { model: "claude-opus | codex" }

# Gate 命令（根据项目工具链修改）
gate:
  lint: "pnpm lint --no-error-on-unmatched-pattern"
  typecheck: "pnpm tsc --noEmit"
  test: "pnpm vitest run"
  build: "pnpm build"
```

完整协议规范详见 [WORKFLOW.md](WORKFLOW.md)。
