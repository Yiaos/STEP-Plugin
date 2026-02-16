# STEP（Stateful Task Execution Protocol）

STEP 是一个 opencode 插件，为 AI 编码代理提供全生命周期开发协议。它通过状态机、硬性门禁和 Session 恢复机制，把"看似完成"的工作变成"可验证完成"。

## 1. 为什么做 STEP（Problem Statement）

在使用 LLM 编码代理（opencode、codex、claude code）时，存在两个核心痛点：

1. **任务完成度不足**：MVP 任务看起来"完成了"但实际有 bug 和缺失场景。即使要求 BDD/TDD，agent 也经常跳过边界情况、错误处理。缺乏硬性门禁机制来阻止"假完成"。
2. **跨 Session 上下文丢失**：中断后恢复工作时，背景丢失，需要重新解释。新 session 的方案可能与之前冲突。现有工具（planning-with-files, openspec）记录计划但不强制执行约束。

缺失的关键能力是：**任务状态机 + 硬性质量门禁 + Session 恢复协议 + 需求漂移防护**，并通过 hooks 强制执行（不仅仅是 prompt）。

## 2. STEP 解决什么问题（What STEP Does）

STEP 提供 6 阶段生命周期：

| Phase | 名称 | 目标 |
| --- | --- | --- |
| 0 | Discovery | 开放式讨论，澄清问题与目标 |
| 1 | PRD | 选择题确认，确认 baseline |
| 2 | Tech Design | 开放式讨论，锁定 ADR |
| 3 | Plan & Tasks | BDD 场景矩阵 |
| 4 | Execution | TDD + Gate 质量门禁 |
| 5 | Review | 需求合规 > 代码质量 |

关键机制：

- BDD 场景矩阵：每个场景有 ID，测试名必须包含 ID，100% 覆盖才能通过
- Gate 门禁：lint + typecheck + test + scenario coverage
- SessionStart Hook 自动恢复状态
- baseline 活快照 + 变更审计链防漂移
- Post-MVP 流程（新增功能、Hotfix、约束变更）同样遵循 STEP

## 3. 整体架构（Architecture）

### 执行流程

```
                    ┌──────────────────────────────────────────────────────┐
                    │  opencode 启动                                       │
                    │  ├── 加载 agents/*.md → 注册 6 个 subagent           │
                    │  └── oh-my-opencode preset → 覆盖各 agent 的 model   │
                    └──────────────────────────────────────────────────────┘
                                          │
                                          ▼
                    ┌──────────────────────────────────────────────────────┐
                    │  SessionStart Hook                                   │
                    │  ├── 检测 .step/state.yaml → 注入状态到上下文        │
                    │  ├── 注入 routing 表 → LLM 知道阶段→agent 映射       │
                    │  └── 注入 SKILL.md → LLM 知道协议规则                │
                    └──────────────────────────────────────────────────────┘
                                          │
                                          ▼
  ┌─────────────────────────────────────────────────────────────────────────────────┐
  │  Full Mode                                                                      │
  │                                                                                 │
  │  Phase 0 Discovery ─→ Phase 1 PRD ─→ Phase 2 Tech ─→ Phase 3 Plan              │
  │  @step-pm (opus)       @step-pm       @step-architect   @step-architect          │
  │  开放式讨论              选择题确认      开放式讨论         结构化确认               │
  │                                        @step-designer                            │
  │                                        (UI 方向时)                               │
  │                                                               │                  │
  │                                                               ▼                  │
  │                                                        Phase 3 场景补充           │
  │                                                        @step-qa (opus)           │
  │                                                        追加 edge/error 场景       │
  │                                                               │                  │
  │                                                               ▼                  │
  │  Phase 4 Execution ──────────────────────────────────────────────────             │
  │  ├── 测试编写: @step-qa (routing.test_writing) ← 对抗性                           │
  │  ├── 后端实现: @step-developer (file_routing.backend)                             │
  │  ├── 前端实现: @step-designer (file_routing.frontend)                             │
  │  ├── Gate: gate.sh quick|lite|full {slug} ← 硬保证                               │
  │  └── Gate 失败: @step-qa 分析根因 → 分级修复（最多 3 轮）                          │
  │                         │                                                        │
  │                         ▼                                                        │
  │  Phase 5 Review                                                                  │
  │  @step-reviewer (codex)                                                          │
  │  需求合规(P0) > 代码质量(P1-P3) → Commit → 更新 state.yaml                        │
  └─────────────────────────────────────────────────────────────────────────────────┘

  ┌─────────────────────────────────────────────────────────────────────────────────┐
  │  Lite Mode                                                                      │
  │                                                                                 │
  │  L1 Quick Spec ──→ L2 Execution ──→ L3 Review                                  │
  │  编排器自行处理     @step-qa(测试)     @step-reviewer                             │
  │  (一次确认)         @step-developer    Commit → Check → 归档提示                  │
  │                     @step-designer                                               │
  │                     (自主执行)                                                    │
  └─────────────────────────────────────────────────────────────────────────────────┘
```

### 配置架构（5 层分离）

```
agent .md frontmatter   →  WHO    角色人设 + 默认模型
config.yaml routing     →  WHEN   哪个阶段用哪个 agent
config.yaml file_routing → WHERE  哪些文件用哪个 agent
config.yaml gate        →  HOW    项目构建命令
oh-my-opencode preset   →  WITH   用户环境的实际模型 ID
```

### Agent × Model × Phase 完整映射

| Phase | 阶段 | Agent | 默认 Model | Routing Key |
|-------|------|-------|-----------|-------------|
| 0 | Discovery | @step-pm | claude-opus | routing.discovery |
| 1 | PRD | @step-pm | claude-opus | routing.prd |
| 2 | Tech Design | @step-architect | claude-opus | routing.tech_design |
| 2 | UI 设计方向 | @step-designer | gemini | routing.tech_design（UI 部分） |
| 3 | Planning | @step-architect | claude-opus | routing.planning |
| 3 | 场景补充 | @step-qa | claude-opus | routing.scenario |
| 4 | 测试编写 | @step-qa | claude-opus | routing.test_writing |
| 4 | 后端实现 | @step-developer | codex | file_routing.backend |
| 4 | 前端实现 | @step-designer | gemini | file_routing.frontend |
| 4 | Gate 失败分析 | @step-qa | claude-opus | — |
| 5 | Review | @step-reviewer | codex | routing.review |

### 硬保证 vs 软保证

| 层 | 机制 | 保证类型 |
|----|------|---------|
| gate.sh / scenario-check.sh | 脚本执行，退出码决定 pass/fail | **硬保证** |
| Agent 模型绑定 | frontmatter + preset，框架层强制 | **硬保证** |
| SessionStart Hook 注入 | bash 脚本，确定性执行 | **硬保证** |
| 阶段流转 / TDD 先测试 | SKILL.md 规则 + agent Critical Actions | 软保证（prompt） |
| 按 routing 表派发 agent | LLM 自主决策 | 软保证（prompt） |
| baseline 确认 | 契约 + changes/ 流程 | 软保证（无文件锁） |

## 4. 安装（Installation）

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
├── commands/
│   ├── step.md             # /step 命令
│   ├── status.md           # /step/status 诊断命令
│   └── archive.md          # /archive 归档命令
├── hooks/
│   ├── hooks.json          # SessionStart hook
│   └── session-start.sh    # 自动检测 .step/ 并注入状态
├── skills/step/SKILL.md    # 核心协议规则
├── scripts/
│   ├── step-init.sh        # 项目初始化
│   ├── gate.sh             # 质量门禁 (quick/lite/full)
│   ├── scenario-check.sh   # BDD 场景覆盖检查
│   └── step-archive.sh     # 变更归档
├── agents/                 # 角色 agent 定义
│   ├── pm.md               # 产品经理 (Phase 0-1)
│   ├── architect.md        # 架构师 (Phase 2-3)
│   ├── qa.md               # 质量工程师 (Phase 3/4/5)
│   ├── developer.md        # 开发者 (Phase 4 后端)
│   ├── designer.md         # UX 设计师 (Phase 2 UI + Phase 4 前端)
│   └── reviewer.md         # Code Reviewer (Phase 5)
└── templates/              # 项目文件模板
```

### 角色系统

STEP 定义 7 个角色，每个角色对应一个 agent 定义（`agents/*.md`），默认模型可通过 oh-my-opencode preset 覆盖：

| 角色 | Agent | 默认模型 | 阶段 | 思维模式 |
| --- | --- | --- | --- | --- |
| PM | @step-pm | claude-opus | Phase 0-1 | 用户视角、需求优先级、验收标准 |
| Architect | @step-architect | claude-opus | Phase 2-3 | 技术权衡、系统设计、任务拆分 |
| QA | @step-qa | claude-opus | Phase 3/4/5 | 对抗性测试思维、根因分析、需求合规 |
| Developer | @step-developer | codex | Phase 4（后端） | TDD 实现、遵循 patterns、不越界 |
| Designer | @step-designer | gemini | Phase 2 UI + Phase 4（前端） | 配色、布局、交互、UI 代码 |
| Reviewer | @step-reviewer | codex | Phase 5 Review | 需求合规审查、代码质量评估 |
| Deployer | @step-deployer | claude-opus | Review 后（可选） | 平台选型、CI/CD、风险评估 |

角色之间形成制衡：PM 定义"做什么"、Architect 定义"怎么做"、QA 定义"怎么破坏它"、Developer/Designer 只做被定义的事。

## 5. 使用（Usage）

```
# 在任何项目中启动 STEP
/step

# 新项目 → 自动初始化 .step/ 目录 → 进入 Phase 0
# 已有项目 → 自动恢复到上次中断的阶段和任务

# 归档已完成的变更
/archive                     # 交互式列出并归档
/archive {change-name}       # 归档指定变更

# 查看当前 STEP 健康度
/step/status
```

## 6. 项目文件结构（Project Files）

`/step` 会在项目中创建：

```
.step/
├── config.yaml          # agent 路由、文件路由、gate 命令
├── baseline.md          # 需求基线（活快照）
├── decisions.md         # 架构决策日志
├── state.yaml           # 项目状态机（Session 恢复核心）
├── changes/             # 所有变更（初始 + 后续）统一管理
│   ├── init/            # 初始开发
│   │   ├── findings.md  # 探索发现（Phase 0/2，可选）
│   │   ├── spec.md      # 需求说明（Phase 1）
│   │   ├── design.md    # 技术方案（Phase 2）
│   │   └── tasks/       # 任务 + BDD 场景（Phase 3）
│   └── YYYY-MM-DD-xxx/  # 后续变更（结构相同）
├── archive/             # 已完成变更归档
└── evidence/            # gate 运行证据
scripts/
├── gate.sh              # 质量门禁
├── scenario-check.sh    # 场景覆盖检查
└── step-worktree.sh     # worktree 创建/归档合并清理
```

### 命名规则

变更和任务都使用语义化命名。初始开发固定 `init`，后续变更使用 `YYYY-MM-DD-{slug}`。任务 slug 使用 kebab-case，Full/Lite 通过 YAML `mode` 字段区分：

| 元素 | 格式 | 示例 |
|------|------|------|
| 变更目录 | `.step/changes/{change}/` | `.step/changes/init/` |
| 变更 findings | `.step/changes/{change}/findings.md` | `.step/changes/init/findings.md`（可选） |
| 变更 spec | `.step/changes/{change}/spec.md` | `.step/changes/init/spec.md` |
| 变更 design | `.step/changes/{change}/design.md` | `.step/changes/init/design.md` |
| 任务文件 | `.step/changes/{change}/tasks/{slug}.yaml` | `.step/changes/init/tasks/user-register-api.yaml` |
| 场景 ID | `S-{slug}-{seq}` | `S-user-register-api-01` |
| 归档 | `.step/archive/YYYY-MM-DD-{change}/` | `.step/archive/2026-02-15-init/` |

## 7. 配置（Configuration）

`.step/config.yaml` 控制 agent 路由、文件分流与 gate 命令，均可自定义：

```yaml
# 阶段 → Agent 路由（删除某行 = 编排器自己处理该阶段）
routing:
  discovery:    { agent: step-pm }
  prd:          { agent: step-pm }
  tech_design:  { agent: step-architect }
  planning:     { agent: step-architect }
  scenario:     { agent: step-qa }
  test_writing: { agent: step-qa, note: "建议与 execution agent 不同，形成对抗性" }
  execution:    { agent: step-developer }
  review:       { agent: step-reviewer }

# Phase 4 文件模式路由（前端文件 → designer，其余 → developer）
file_routing:
  frontend:
    agent: step-designer
    patterns: ["src/components/**", "**/*.tsx", "**/*.css", "**/*.vue"]
  backend:
    agent: step-developer
    patterns: ["src/api/**", "src/db/**", "src/lib/**"]

# Gate 命令（根据项目工具链修改）
gate:
  lint: "pnpm lint --no-error-on-unmatched-pattern"
  typecheck: "pnpm tsc --noEmit"
  test: "pnpm vitest run"
  build: "pnpm build"
  dangerous_executables: ["rm", "dd", "mkfs", "shutdown", "reboot", "poweroff", "halt", "sudo"]

# Worktree 并行开发（可选）
worktree:
  enabled: false
  branch_prefix: "change/"
```

### Worktree 模式

当 `worktree.enabled: true` 时，STEP 流程会遵循以下规则：

- 变更开始阶段自动创建独立 worktree（`scripts/step-worktree.sh create {change}`）
- Commit 完成后询问是否“合并回主分支并归档”
- 用户确认后执行：合并回“创建该 worktree 时所在分支” → 归档 change
- 合并冲突时按策略自动解冲突，并输出冲突文件与采用的解决策略
- 合并完成后自动清理 feature worktree

### 模型配置

Agent 默认模型在 `agents/*.md` frontmatter 中定义。用户可通过 oh-my-opencode preset 按 agent name 覆盖：

```json
{
  "step-pm": { "model": "google/antigravity-claude-opus-4-6-thinking" },
  "step-architect": { "model": "google/antigravity-claude-opus-4-6-thinking" },
  "step-qa": { "model": "google/antigravity-claude-opus-4-6-thinking" },
  "step-reviewer": { "model": "openai/gpt-5.3-codex" },
  "step-developer": { "model": "openai/gpt-5.3-codex" },
  "step-designer": { "model": "google/antigravity-gemini-3-pro" }
}
```

## 8. Lite Mode（快速通道）

对于小型任务（如 `fix-empty-password`、配置变更），STEP 提供 Lite Mode，3 个阶段代替 6 个阶段：

```
L1 Quick Spec → L2 Execution → L3 Review
(一次确认)      (TDD+gate lite)  (完整 Code Review)

Quick 模式用于小改动：`/step quick`，由模型判断是否适用；执行中可升级到 lite/full。
```

### 适用条件

- 影响 ≤ 3 个文件
- 不涉及架构变更
- 已有 baseline 存在

### 触发方式

```bash
# 显式指定 Lite Mode
/step lite

# 显式指定 Full Mode
/step full

# 自动检测（根据输入复杂度判断）
/step
```

### 核心保留 vs 简化

| | Full | Lite |
|---|---|---|
| TDD | ✅ | ✅ |
| BDD 覆盖 | ✅ 100% | ✅ 100% |
| Code Review | ✅ 完整 | ✅ 完整 |
| Gate | lite / full | lite |
| 确认轮数 | 多次 | 一次 |
| 预计时间 | 65-110 min | 10-15 min |

### 归档

变更完成后通过 `/archive` 命令或 "归档 xxx" 归档到 `.step/archive/`：

```
.step/
├── changes/
│   └── init/                              # 活跃变更
│       ├── spec.md
│       ├── design.md
│       └── tasks/
└── archive/
    └── 2026-02-15-init/                   # 已归档变更
```

完整协议规范详见 [WORKFLOW.md](WORKFLOW.md)。
