# STEP: Stateful Task Execution Protocol — 全生命周期方案 v2

> 从"我有个想法"到"代码交付上线"的完整闭环。
> 解决：任务完成度不足、中断后背景丢失、方案漂移、测试质量不够。

---

## 全局流程概览

```
Phase 0         Phase 1        Phase 2        Phase 3         Phase 4           Phase 5
Discovery   →   PRD        →   Tech Design →  Plan & Tasks →  Execution     →   Review
(开放式讨论)     (选择题确认)    (开放式讨论)    (选择题确认)     (TDD+Gate)        (独立验证)
                                                                  ↑
                                                   中断恢复 ──────┘
                                                   读 state.yaml

Post-MVP:
  新增功能/Hotfix/约束变更 → 回到 Phase 1-4（按变更类型）
```

### 对话模式说明

STEP 使用两种对话模式，在不同阶段切换：

| 模式           | 适用阶段                               | 特征                                                       |
| -------------- | -------------------------------------- | ---------------------------------------------------------- |
| **开放式讨论** | Phase 0 Discovery, Phase 2 Tech Design | 用户主导提问方向，LLM 提供信息和分析供讨论，不主动逐个提问 |
| **选择题确认** | Phase 1 PRD 细节, Phase 3 Plan 细节    | LLM 提供结构化选项，逐项确认细节                           |

**关键区别：** Phase 0 和 Phase 2 是用户探索式的，用户提出问题、LLM 回答分析。不是 LLM 每次问一个问题等用户回答。

### 角色与 Agent 映射

STEP 定义 7 个角色，每个角色对应一个 agent 定义文件（`STEP/agents/`），模型可通过 oh-my-opencode preset 覆盖：

| 角色                  | Agent 文件            | 默认模型    | 适用阶段                                            | 思维模式                                            |
| --------------------- | --------------------- | ----------- | --------------------------------------------------- | --------------------------------------------------- |
| PM（产品经理）        | `agents/pm.md`        | claude-opus | Phase 0 Discovery, Phase 1 PRD                      | 用户视角、需求优先级、验收标准                      |
| Architect（架构师）   | `agents/architect.md` | claude-opus | Phase 2 Tech Design, Phase 3 Plan                   | 技术权衡、系统设计、任务拆分                        |
| QA（质量工程师）      | `agents/qa.md`        | claude-opus | Phase 3 场景补充, Phase 4 Gate 分析, Phase 5 Review | 对抗性测试思维、根因分析、需求合规                  |
| Reviewer（代码审查）  | `agents/reviewer.md`  | codex       | Phase 5 Review, Lite L3                             | 需求合规审查、代码质量评估、参考 code-review-expert |
| Deployer（部署策略）  | `agents/deployer.md`  | claude-opus | Review 后（可选）                                   | 平台选型、CI/CD、环境清单、风险评估                 |
| Developer（开发者）   | `agents/developer.md` | codex       | Phase 4 Execution（后端）                           | TDD 实现、遵循 patterns、不越界                     |
| Designer（UX 设计师） | `agents/designer.md`  | gemini      | Phase 2 UI 设计, Phase 4 Execution（前端）          | 配色、布局、交互设计、UI 代码                       |

**角色切换原则：**
- 每个 Phase 有默认角色，通过 `.step/config.yaml` 的 `routing` 表配置
- Phase 4 执行时，按 `file_routing` 表的 patterns 匹配决定用 Designer 还是 Developer
- 角色之间形成制衡：PM 定义"做什么"、Architect 定义"怎么做"、QA 定义"怎么破坏它"、Developer/Designer 只做被定义的事
- Agent 默认模型在 `agents/*.md` frontmatter 中定义，用户可通过 oh-my-opencode preset 按 agent name 覆盖

### 文件结构

```
.step/
├── config.yaml               # 项目配置（agent 路由、文件路由、gate 命令）
├── baseline.md                # 需求基线（活快照）
├── decisions.md               # Phase 2 输出：架构决策日志
├── state.yaml                 # Phase 3+ 持续更新：项目状态机
├── changes/                   # 所有变更（初始 + 后续）统一管理
│   ├── init/                  # 初始开发
│   │   ├── findings.md        # 探索发现（Phase 0/2，可选）
│   │   ├── spec.md            # 需求说明（Phase 1 产出）
│   │   ├── design.md          # 技术方案（Phase 2 产出）
│   │   └── tasks/             # 任务 + BDD 场景（Phase 3 产出）
│   │       ├── user-register-api.yaml
│   │       └── ...
│   └── 2026-02-20-add-dark-mode/  # 后续变更
│       ├── spec.md
│       ├── design.md
│       └── tasks/
│           └── dark-mode-toggle.yaml
├── archive/                   # 已完成变更归档
│   └── 2026-02-15-init/
└── evidence/
    ├── user-register-api-gate.json      # gate 运行结果（gate.sh 自动生成）
    ├── user-register-api-scenario.json  # 场景覆盖结果（scenario-check.sh 自动生成）
    └── user-register-api-review.md      # Review 报告（@step-reviewer 手动写入）
scripts/
├── gate.sh                    # 质量门禁
├── scenario-check.sh          # 场景覆盖检查
├── step-archive.sh            # 变更归档
└── step-worktree.sh           # worktree 创建/归档合并清理
```

---

## Phase 0: Discovery（开放式讨论）

**目的：** 在自由讨论中确定整体方向和目标。  
**方式：** 用户主导对话方向，LLM 提供信息、分析、对比。用户提问，LLM 回答。  
**推荐模型：** Claude Opus

### 核心规则

1. **用户主导**：用户描述想法、提出问题、表达困惑。LLM 不主动逐个提问。
2. **LLM 的角色是"对话伙伴"**：提供分析、指出风险、给出建议，但不引导方向。
3. **讨论范围不限**：可以聊商业模式、技术可行性、竞品分析、用户场景。
4. **不做技术决策**：不在这个阶段选框架、选数据库。
5. **不写代码**。

### 流程

```
用户: "我想做一个 XXX"

LLM: 理解你的想法，给出初步看法（200字以内）。
     如果描述模糊，可以问 1-2 个澄清问题（但不是逐个提问式）。

用户: [继续描述 / 提出问题 / 讨论方向]

LLM: 回应用户的问题，提供分析。
     当讨论自然收敛时，提出总结：
     "我理解的大方向是... 要进入需求细化阶段吗？"

用户: "对，可以了" / "还有一个问题..."

→ 用户确认后进入 Phase 1
```

### 什么时候结束 Phase 0

当以下条件都满足时：
- 目标方向明确（做什么、给谁用）
- 大致边界清晰（做什么、不做什么）
- 用户说"差不多了"或"可以继续了"

Phase 0 **不需要** 完美的需求文档。它的输出是"双方对方向达成共识"。

### findings.md（可选）

如果探索过程中产生了关键发现（现有代码结构、技术约束、性能数据等），写入 `.step/changes/{change}/findings.md`。这些事实性信息会在 Session 恢复时自动注入上下文，避免重复调研。

- **什么写 findings**：事实性发现（"数据库连接池上限 5"、"这个库不支持 SSR"）
- **什么写 decisions**：重大发现应提炼为 ADR 写入 `decisions.md`（"选了 A 不选 B，因为 findings 发现 B 不支持 X"）
- **什么写 baseline**：跨变更的通用约束应沉淀到 `baseline.md` Constraints

---

## Phase 1: PRD（选择题确认细节）

**目的：** 把 Phase 0 的共识固化为结构化文档。  
**方式：** LLM 起草文档 → 分段展示 → 选择题确认细节。  
**推荐模型：** Claude Opus

### 流程

```
LLM 基于 Phase 0 讨论起草 baseline.md
  │
  ├── 分段展示，每段确认：
  │     "Goal 和 Non-Goal 部分：... 这样对吗？"
  │     "MVP Scope 部分，以下哪些功能是必须的？" [多选]
  │     "约束部分，以下哪些是硬约束？" [多选]
  │
  └── 全部确认后写入 .step/baseline.md
```

### `.step/baseline.md` 格式

```markdown
# Baseline

## Goal
一句话：为 [目标用户] 提供 [核心能力]，解决 [核心问题]。

## Non-Goal（明确不做的事）
- NG-1: 不做 XXX
- NG-2: 不做 YYY

## MVP Scope（按优先级排序）
- [ ] F-1: 功能 1（核心）
- [ ] F-2: 功能 2（核心）
- [ ] F-3: 功能 3（重要）

## User Stories
- US-1: 作为 [角色]，我希望 [做什么]，以便 [达到什么目的]

## Acceptance Contract（验收口径）
- AC-1: [具体的、可测试的条件]

## Constraints（不可违反约束）
- C-1: [约束内容]

## 状态
- 确认时间: YYYY-MM-DD
- 修改方式: 必须通过新建变更（`.step/changes/YYYY-MM-DD-{slug}/`）
```

---

## Phase 2: Tech Design（开放式讨论 → 锁定）

**目的：** 对比技术方案，确定技术栈和架构。  
**方式：** LLM 提供全面的技术方案分析 → 用户开放讨论 → 达成共识后锁定。  
**推荐模型：** Claude Opus

### 核心规则

1. **不是让用户从 A/B/C 里选一个**。是 LLM 详细说明所有可行方案的优劣势，然后用户开放讨论。
2. 用户可以提出 LLM 没考虑到的方案。
3. 用户可以追问细节："X 方案在高并发下表现如何？""Y 和 Z 能不能混用？"
4. LLM 应该给出推荐和理由，但不替用户做决定。
5. 整体架构确认后，细节选择可以用选择题快速确认。

### 流程

```
LLM 读取 baseline.md，给出全面技术分析：

  "基于你的需求，以下是可行的技术方案：

   方案 A: Next.js + Prisma + PostgreSQL
   - 优势: SSR、类型安全、全栈一体
   - 劣势: 较重、冷启动慢
   - 适合: 偏展示型、SEO 重要的场景

   方案 B: Hono + Drizzle + SQLite
   - 优势: 极轻量、部署简单
   - 劣势: 生态小
   - 适合: API 为主、快速迭代

   方案 C: ...

   我个人倾向方案 B，因为... 但如果你有不同想法我们可以讨论。"

用户: "方案 B 的 SQLite 在多用户并发写入时有问题吗？"

LLM: [详细分析 SQLite 并发能力...]

用户: "那如果用 PostgreSQL 配合 Hono 呢？"

LLM: [分析混合方案...]

用户: "好，就用 Hono + Drizzle + PostgreSQL"

LLM: "好的，整体架构确定了。还有几个细节需要确认：
      测试框架？ A) Vitest  B) Node.js 内置  ← 这里用选择题
      部署方式？ A) Docker  B) 直接部署"

用户: A, A

LLM: → 写入 .step/changes/{change}/design.md + .step/decisions.md
```

### 输出物

- `.step/changes/{change}/design.md`：技术方案
- `.step/decisions.md`：ADR 日志
- 更新 `baseline.md` 的 Tech Stack

---

## Phase 3: Plan & Tasks（结构化确认）

**目的：** 把需求拆成可执行的任务序列，每个任务带 BDD 场景。  
**方式：** LLM 生成任务图 → 用户审核确认。  
**推荐模型：** Claude Opus

### 场景矩阵（BDD 规则）

每个任务的场景矩阵就是 BDD（Behavior-Driven Development）的 Given/When/Then。

每个场景通过 `test_type` 字段指定验证方式，所有类型的测试都是必须的：

```
BDD 场景 (Given/When/Then) — 行为规格
    │
    ├── unit test      — 隔离验证单个模块逻辑（必须）
    ├── integration test — 验证多模块协作（必须）
    └── e2e test       — 验证端到端关键路径（必须）
```

- 场景定义的是**行为规格**（什么输入 → 什么输出）
- `test_type` 字段指定该场景用哪种测试验证
- 三种测试类型都是必须的，不是可选的
- 每个场景的 `test_type` 在 Phase 3 规划时确定

### 任务 YAML 格式

```yaml
# 文件名: .step/changes/{change}/tasks/user-register-api.yaml
id: user-register-api          # 语义化 slug = 文件名（不含 .yaml）
title: "用户注册 API"
mode: full                     # full | lite
status: planned                # planned | ready | in_progress | blocked | done
depends_on: [user-model-setup]
goal: "实现 POST /api/register"
non_goal:
  - "不做 OAuth"

# 完成条件（命令级）
done_when:
  - "pnpm lint"
  - "pnpm tsc --noEmit"
  - "pnpm vitest run test/auth/register.test.ts"

# BDD 场景矩阵（4 类必须覆盖）
scenarios:
  happy_path:
    - id: S-user-register-api-01
      given: "email=test@x.com, password=Valid123!"
      when: "POST /api/register"
      then: "返回 201 + { data: { id, email } }"
      test_file: "test/auth/register.test.ts"
      test_name: "[S-user-register-api-01] 正常注册成功"
      test_type: unit  # unit | integration | e2e
      status: not_run

  edge_cases:
    - id: S-user-register-api-02
      given: "email 已被注册"
      when: "POST /api/register"
      then: "返回 409"
      test_file: "test/auth/register.test.ts"
      test_name: "[S-user-register-api-02] 重复邮箱注册"
      test_type: unit
      status: not_run

    - id: S-user-register-api-03
      given: "password 少于 8 位"
      when: "POST /api/register"
      then: "返回 400"
      test_file: "test/auth/register.test.ts"
      test_name: "[S-user-register-api-03] 密码太短"
      test_type: unit
      status: not_run

  error_handling:
    - id: S-user-register-api-04
      given: "数据库连接失败"
      when: "POST /api/register"
      then: "返回 503"
      test_file: "test/auth/register.test.ts"
      test_name: "[S-user-register-api-04] 数据库不可用"
      test_type: integration
      status: not_run

# 场景覆盖要求
coverage_requirements:
  happy_path: 1+
  edge_cases: 2+
  error_handling: 1+
  security: "按需"

rollback: "git revert --no-commit HEAD~3"
```

### 命名规则

| 元素       | 格式                                      | 示例                                              |
| ---------- | ----------------------------------------- | ------------------------------------------------- |
| 变更目录   | `.step/changes/{change}/`                 | `changes/init/`, `changes/2026-02-20-add-oauth/`  |
| 变更 spec  | `.step/changes/{change}/spec.md`          | `changes/init/spec.md`                             |
| 变更 design| `.step/changes/{change}/design.md`        | `changes/init/design.md`                            |
| 任务文件   | `.step/changes/{change}/tasks/{slug}.yaml`| `changes/init/tasks/user-register-api.yaml`        |
| 任务 ID    | `{slug}`                                  | `user-register-api`                                |
| 场景 ID    | `S-{slug}-{seq}`                          | `S-user-register-api-01`                           |
| 归档       | `.step/archive/YYYY-MM-DD-{change}/`      | `archive/2026-02-15-init/`                         |
| Evidence   | `{slug}-gate.json`                        | `user-register-api-gate.json`                      |
| Evidence   | `{slug}-scenario.json`                    | `user-register-api-scenario.json`                  |

**Slug 命名原则（参考 OpenSpec）：**
- 使用小写英文 + 连字符（kebab-case）
- 描述任务核心内容：`fix-empty-password`、`add-dark-mode`、`user-register-api`
- 避免含义模糊的缩写：`impl-auth`（❌）→ `user-register-api`（✅）
- 不使用序号前缀：`001-user-register`（❌）→ `user-register-api`（✅）

---

## Phase 4: Execution（TDD + Gate）

**多模型编排：** 所有工具统一使用 opencode，通过 opencode 的模型配置切换底层模型。

### Agent 路由

Phase 4 执行时，编排器按 `.step/config.yaml` 的路由表选择 agent：

```yaml
# .step/config.yaml

# 阶段 → Agent 路由（编排器参考此表派发子 agent）
routing:
  discovery:    { agent: step-pm }
  prd:          { agent: step-pm }
  lite_spec:    { agent: step-pm, note: "Lite L1 Quick Spec，轻量需求确认" }
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

# Gate 命令（根据项目包管理器和工具链修改）
gate:
  lint: "pnpm lint --no-error-on-unmatched-pattern"
  typecheck: "pnpm tsc --noEmit"
  test: "pnpm vitest run"
  build: "pnpm build"

# Worktree 并行开发（可选）
worktree:
  enabled: false
  branch_prefix: "change/"
```

### 执行循环

```
Step 1: 加载上下文
  读 state.yaml → 读 task YAML → 读 baseline.md
  输出: "📍 user-register-api 用户注册 | 4 场景待实现"

Step 2: 写测试（按 routing.test_writing 派发 @step-qa）
  ┌────────────────────────────────────────────────┐
  │ 读取 .step/changes/{change}/tasks/user-register-api.yaml 的场景矩阵│
  │ 为每个场景写测试，名称包含 [S-{slug}-xx]          │
  │ 不写任何实现代码                                  │
  │ 跑测试确认全部 FAIL                               │
  │ QA 写测试 + Developer 写实现 = 天然对抗性          │
  └────────────────────────────────────────────────┘
  → 确认全部 FAIL（TDD RED）

Step 3: 写实现（按 config.yaml file_routing 选 agent）
  若 `config.worktree.enabled=true`:
    → 自动执行 `./scripts/step-worktree.sh create {change-name}`
    → 在该变更的独立 worktree 中继续执行 Phase 4
  前端文件（匹配 file_routing.frontend.patterns）→ @step-designer
  后端文件（匹配 file_routing.backend.patterns）→ @step-developer
  未匹配的文件 → @step-developer（默认）
  → 每实现一个场景，跑 gate lite

Step 4: Gate 验证
  ./scripts/gate.sh quick user-register-api  # 小改动快速门禁
  ./scripts/gate.sh lite user-register-api   # 常规增量测试
  # Review 前或归档前
  ./scripts/gate.sh full user-register-api --all
  → 包含场景覆盖检查（scenario-check.sh）
  → 通过 → Step 5
  → 失败 → Gate 失败处理流程（见下方）

Step 5: Review + Commit（每完成一个任务都执行）
  ┌────────────────────────────────────────────────┐
  │ Gate 通过后：                                    │
  │                                                │
  │ 0. Polish（Full mode 限定，Lite 跳过）           │
  │    由 @step-designer 执行打磨检查：              │
  │    - loading 状态和骨架屏                        │
  │    - 错误提示友好性（用户能理解并行动）            │
  │    - 空状态处理（首次使用引导）                   │
  │    - 过渡动画和视觉反馈                          │
  │    - 跨设备/响应式验证                           │
  │                                                │
  │ 1. Review 第一轮: Spec Compliance（需求合规）      │
  │    对照 baseline → PRD → BDD 场景 → ADR          │
  │    展示 gate + scenario-check 最新输出作为证据    │
  │    → 不通过 → REQUEST_CHANGES，不进入第二轮       │
  │                                                │
  │ 2. Review 第二轮: Code Quality（代码质量）        │
  │    SOLID + 安全 + 性能 + 边界条件                │
  │    仅在第一轮通过后执行                          │
  │                                                │
  │ 3. Review 通过 → Commit                         │
  │    git add + commit（提交信息包含 task slug）     │
  │    例: "feat(auth): user-register-api [4/4 S]"  │
  │    Commit 后输出简短摘要：做了什么、为什么、影响  │
  │    worktree 模式下：                              │
  │      询问是否合并回主分支并归档                  │
  │      用户确认后执行 `step-worktree.sh finalize`  │
  │                                                │
  │ 4. Review 不通过 → 修复 → 重新 Gate → 重新 Review│
  └────────────────────────────────────────────────┘

Step 6: 更新状态
  Review 通过 + Committed → status: done
  → 同步更新 baseline.md: 将对应功能项 [ ] 标记为 [x]
  未完成 → status: in_progress + 具体 next_action
  → 进入下一个任务的 Step 1
```

---

## Gate 失败处理流程

当 `gate.sh` 报告失败时，不是简单地"回去修"。有两个阶段：**失败分析** + **分级修复**。

### 阶段 1: 失败原因分析（指定 Claude Opus 或 Codex xhigh）

Gate 失败后，**必须**先用高推理能力模型做根因分析，不能直接盲修：

```
失败分析 agent（Claude Opus 或 Codex xhigh）:
  输入: gate 输出日志 + 失败的测试/lint/typecheck 错误
  输出:
    1. root_cause: "具体原因（一句话）"
    2. category: lint | typecheck | test_logic | test_coverage | build
    3. fix_strategy: ["策略A: ...", "策略B: ..."]  # 可能多个
    4. affected_files: ["file:line", ...]
    5. risk: "修复可能影响的其他模块"
  
  如有多种修复策略 → 展示选项给用户选择，而非自动选第一个
```

**为什么要用强模型分析：** 直接让执行 agent 看到报错就改，容易改表面不改根因，导致反复失败。先分析再修，一次修对的概率显著更高。

### 阶段 2: 分级修复

基于分析结果，按类别处理：

```
Gate 分级修复
  │
  ├── lint 失败
   │     → 自动修复: 按分析结果修复 → 重跑 gate lite
  │     → 通常不需要人工干预
  │
  ├── typecheck 失败
   │     → 按分析结果修复 → 重跑 gate lite
  │     → 如果分析指出涉及接口变更 → 检查是否违反 baseline 约束
  │
  ├── 测试失败
  │     → 根据分析的 root_cause 判断：
  │       → 实现 bug → 修复实现代码（不改测试）
  │       → 测试写错 → 修复测试代码
  │     → 重跑失败的测试
  │
  ├── 场景覆盖不足（scenario-check 失败）
  │     → 列出缺失的场景 ID
  │     → 为每个缺失场景补充测试
  │     → 重跑 scenario-check
  │
  └── build 失败
        → 按分析结果修复 → 重跑 gate full

修复循环规则:
  1. 每轮修复前都先跑一次失败分析（不盲修）
  2. 最多自动修复 3 轮
  3. 3 轮后仍失败 → 标记 blocked + 请求人工介入
```

### Gate 失败后的状态更新规则

```
  1. 任务状态保持 in_progress（不允许标 done）
  2. state.yaml 记录:
     - gate_results: { lint: pass, test: fail, ... }
     - failure_analysis: "root_cause + fix_strategy（来自分析 agent）"
     - blocking_issues: ["test/auth/register.test.ts:42 - 预期 201 实际 500"]
     - next_action: "修复 src/auth/register.ts:42 的错误处理逻辑（根因: 缺少 isLocked 判断）"
  3. 3 轮后仍失败:
     state.yaml:
       current.status: blocked
       current.blocking_issues: ["3 次自动修复失败，需要人工排查"]
       current.failure_history: ["轮次1: ...", "轮次2: ...", "轮次3: ..."]
```

---

## Phase 5: Review（独立验证）

**模型：** 可选（Claude Opus / Codex / 其他），用户根据需要指定  
**触发时机：** 每完成一个任务（task）都可以触发 Review + Commit，不必等全部完成

### Review 两阶段：Spec Compliance → Code Quality

Review 分两轮执行。第一轮不通过则阻断，**不进入第二轮**。

**第一轮：Spec Compliance（需求合规 — 阻断）**

<HARD-GATE>
第一轮未通过前，禁止进行代码质量审查。spec 都不达标时讨论代码风格没有意义。
</HARD-GATE>

```
═══════════════════════════════════════
  第一轮：Spec Compliance（不通过则阻断）
═══════════════════════════════════════

1. Baseline 合规
   □ 是否违反了 baseline.md 的任何 Constraints？
   □ 实现是否在 MVP Scope 范围内？
   □ 是否做了 Non-Goal 中明确排除的事？

2. PRD / User Story 验证
   □ 每个 User Story 是否有对应的代码实现？
   □ Acceptance Contract 中的条件是否全部满足？

3. BDD 场景覆盖
   □ task YAML 中的每个场景是否都有通过的测试？
   □ happy_path / edge_cases / error_handling 是否都覆盖？
   □ scenario-check.sh 是否 100% pass？

4. Plan / ADR 一致性
   □ 实现是否与 decisions.md 中的 ADR 一致？
   □ 是否引入了未经 ADR 记录的架构决策？
   □ 任务依赖关系是否正确（不跳步）？

5. Test Quality（测试本身是否可信）
   □ 测试是否真正验证了行为（不是 mock 自己）？
   □ 有没有"假测试"（expect(true).toBe(true)）？
   □ edge case 是否有效（真的传了空值/错误值）？

6. 验证铁律
   □ 声称"需求合规通过"前，必须展示 gate + scenario-check 最新输出
   □ 没有新鲜证据的通过声明等于撒谎
```

→ 通过 → 明确声明"第一轮 Spec Compliance 通过"+ 证据引用 → 进入第二轮
→ 不通过 → 输出 P0 问题列表 → REQUEST_CHANGES → **停止，不进入第二轮**

**第二轮：Code Quality（代码质量 — 仅在第一轮通过后执行）**

```
═══════════════════════════════════════
  第二轮：Code Quality（仅在第一轮通过后）
═══════════════════════════════════════

7. SOLID + Architecture Smells
   □ SRP: 模块职责是否单一？
   □ OCP: 是否通过扩展而非修改来增加行为？
   □ LSP: 子类是否满足基类契约？
   □ ISP: 接口是否最小化？
   □ DIP: 高层是否依赖抽象？

8. Security & Reliability
   □ XSS、注入（SQL/NoSQL/命令）、SSRF、路径穿越
   □ AuthZ/AuthN 缺口、多租户隔离
   □ 密钥泄露、日志中的敏感信息
   □ 竞态条件、TOCTOU、缺少锁

9. Code Quality
   □ 错误处理：吞异常、过宽 catch、缺失错误处理
   □ 性能：N+1 查询、热路径计算密集、缺失缓存
   □ 边界条件：null/undefined、空集合、数值边界、off-by-one
```

**严重程度分级（参考 code-review-expert）：**

| 级别 | 名称     | 描述                                | 行动           |
| ---- | -------- | ----------------------------------- | -------------- |
| P0   | Critical | 需求不合规、安全漏洞、数据丢失      | 必须阻断       |
| P1   | High     | 场景缺失、逻辑错误、SOLID 严重违反  | 合并前修复     |
| P2   | Medium   | 代码异味、可维护性、轻微 SOLID 违反 | 本轮或后续修复 |
| P3   | Low      | 风格、命名、小建议                  | 可选改进       |

**关键区别：** P0 新增"需求不合规"。之前 P0 只有安全和数据丢失，现在 baseline 违反、场景缺失也是 P0。

**Review 输出格式：**

```markdown
## Code Review Summary
**Files reviewed**: X files, Y lines changed
**Overall assessment**: [APPROVE / REQUEST_CHANGES / COMMENT]

### P0 - Critical
(none or list)

### P1 - High
- **[file:line]** 简述
  - 问题描述
  - 建议修复方式

### P2 - Medium
...

### P3 - Low
...

### Suggested Improvements (v2 建议)
- (改进建议列表，不阻断当前交付)

### Handoff Checklist (可选)
- [ ] 部署就绪？
- [ ] 用户文档/README 更新？
- [ ] 维护指南？
```

### Review Agent

Phase 5 Review 由 `@step-reviewer` 执行（参考 code-review-expert skill 实现）。
审查优先级：需求合规（P0 阻断） > 代码质量（P1-P3）。

---

## Deploy（可选阶段）

Phase 5 Review 通过后，用户可选择触发部署策略建议。由 `@step-deployer` 执行。

**触发方式：**
- 用户说"部署"/"上线"/"deploy"
- Handoff Checklist 中勾选"部署就绪"
- `/step/init deploy`（如果项目需要）

**输出内容：**
1. 项目类型和规模评估
2. 推荐部署方案（主选 + 备选，含成本估算）
3. 环境清单（账号/密钥/DNS/监控）
4. CI/CD pipeline 建议（模板方向，非完整文件）
5. 风险评估和回滚策略

**注意：** Deployer 只提供建议，不自动执行部署命令。用户确认后可协助生成具体配置。

---

## Post-MVP: 统一变更流程（新增功能 / Hotfix / 约束变更）

MVP 完成后不是终点。后续的需求变更、bug 修复**同样遵循 STEP 协议**，所有过程记录在 `.step/` 下。

### 核心原则

Post-MVP 的每一次变更都必须：
1. **有记录** — 变更目录写入 `.step/changes/{change}/`（spec + design + tasks）
2. **有场景** — 新增/修改的行为必须有 BDD 场景矩阵
3. **有验证** — 走 gate（hotfix 必须 gate full 回归）
4. **有审查** — Review + Commit，与 MVP 执行阶段相同

### 场景 1: 需求变更（新功能 / 修改行为）

```
用户: "MVP 用起来不错，但需要加一个 OAuth 登录"
  │
  ├── 1. 创建变更文件夹
  │     mkdir .step/changes/2026-02-14-add-oauth-login/tasks/
  │     写入 spec.md（背景 + 需求 + 影响范围）
  │     写入 design.md（技术方案）
  │
  ├── 2. 用户确认 spec
  │     确认 → 继续; 撤回 → 删除变更文件夹
  │
  ├── 3. 创建任务
  │     写入 tasks/{slug}.yaml（含完整 BDD 场景矩阵）
  │     更新 state.yaml: current_change → 2026-02-14-add-oauth-login
  │
  ├── 4. Phase 4 执行（TDD + Gate + Review + Commit）
  │
  ├── 5. 更新 baseline.md 反映最新状态
  │
  └── 6. 归档变更
        mv .step/changes/2026-02-14-add-oauth-login/ .step/archive/
```

### 场景 2: Bug 修复（Hotfix）

```
用户: "注册时空密码没报错"
  │
  ├── 1. 定位问题
  │     → 读 state.yaml 找到对应任务（user-register-api）
  │     → 读 task YAML 找到对应场景（S-user-register-api-03 密码太短）
  │     → 检查场景 status（如果是 pass → 测试没覆盖到这个 case）
  │
  ├── 2. 创建 Hotfix 变更
  │     mkdir .step/changes/2026-02-14-register-hotfix/tasks/
  │     写入 spec.md（bug 描述 + 根因 + 影响）
  │     写入 design.md（修复方案 + 风险）
  │     写入 tasks/register-empty-password.yaml:
  │       id: register-empty-password
  │       mode: lite
  │       scenarios:
  │         - id: S-register-empty-password-01
  │           given: "password 为空字符串"
  │           when: "POST /api/register"
  │           then: "返回 400"
  │           test_type: unit
  │           status: not_run
  │
  ├── 3. TDD 修复（完整 Phase 4 流程）
   │     → 先写失败测试 → 修复代码 → gate lite → Review + Commit
  │
  └── 4. 回归验证
        → gate full（确保不破坏其他功能）
        → 归档变更到 .step/archive/
```

### 场景 3: 约束变更（影响大）

```
用户: "我们需要把 cookie session 改成 JWT"
  │
  ├── 1. 创建约束变更
  │     mkdir .step/changes/2026-02-14-migrate-cookie-to-jwt/tasks/
  │     写入 spec.md:
  │       type: constraint_change
  │       冲突: baseline C-3（使用 cookie）+ ADR-003
  │       影响: user-register/login/profile API + auth middleware
  │
  ├── 2. 影响分析 + design.md
  │     分析受影响文件和测试 → 写入 design.md
  │
  ├── 3. 用户确认 spec → 创建迁移任务
  │     写入 tasks/migrate-cookie-to-jwt.yaml（含场景矩阵）
  │
  ├── 4. 执行迁移（完整 Phase 4 流程）
  │     → TDD + gate full + Review + Commit
  │
  └── 5. 更新 baseline + decisions → 归档变更
```

### 场景 4: Baseline 整理（低频维护）

经过多轮变更/Hotfix 后，baseline 可能累积大量追加项、已移除功能、被替换的约束，可读性下降。此时可进行一次"整理"：

```
用户: "整理一下 baseline"
  │
  ├── 1. 归档旧版
  │     mv .step/baseline.md .step/archive/YYYY-MM-DD-baseline-v{N}.md
  │
  ├── 2. 整理干净版本
  │     读取旧 baseline + 所有已归档变更 + decisions.md
  │     整理只反映当前状态的新 baseline.md：
  │       - 已移除的功能项直接删掉（不留删除线）
  │       - 被变更修改过的约束直接写新值
  │       - 已完成的保持 [x]，未完成的保持 [ ]
  │       - 注明"整理自 v{N}"
  │
  ├── 3. 用户确认
  │     展示新版 baseline → 用户确认
  │
   ├── 4. 同时精简 state.yaml
   │     - 合并冗余 progress_log 条目为一条总结
   │     - 清理已解决的 known_issues
   │     - 只保留仍有参考价值的 key_decisions
   │     - 清理失效的 current_change/current task 指针（若已归档）
  │
  ├── 5. 同时精简 decisions.md
  │     归档旧版到 .step/archive/YYYY-MM-DD-decisions-v{N}.md
  │     只保留支撑当前 baseline 的核心 ADR：
  │       - 合并琐碎/纯实现细节的条目
  │       - 已被后续 ADR 覆盖的旧决策可移除
  │       - 保留解释"当前为什么是这样"的决策
  │
  ├── 6. 用户确认
  │     展示新版 baseline + state.yaml + decisions.md 变更 → 用户确认
  │
  └── 7. 写入
        写入 .step/baseline.md + .step/state.yaml + .step/decisions.md
        审计链通过归档文件保留，当前文件只负责"现在是什么、为什么"
```

**注意：** 这不是"重建"baseline（方向变了应该重新 Phase 0-1），而是在方向不变的前提下整理格式。不需要专门命令，自然语言触发即可。

---

## 场景覆盖验证机制

### scenario-check.sh 工作原理

```
任务 YAML 定义:  id: S-user-register-api-01
        ↓ 约定
测试文件中写:   it('[S-user-register-api-01] 正常注册', ...)
        ↓ grep 匹配
scenario-check.sh: grep "\[S-user-register-api-01\]" test/auth/register.test.ts
        ↓
匹配到 → covered    匹配不到 → FAIL
```

gate.sh 在 lite/full 级别自动调用 scenario-check.sh。

## 测试代码生成策略

### 四层分离（解决"自己出题自己答"问题）

```
Layer 1: 场景定义    ← Phase 3 Architect（happy_path）+ QA（edge/error/security）
Layer 2: 测试代码    ← Phase 4 @step-qa（按 config.yaml test_writing 路由，形成对抗性）
Layer 3: 实现代码    ← Phase 4 Developer/Designer（按 file_routing 选 agent）
Layer 4: 独立审查    ← Phase 5 QA（需求合规 + 代码质量）
```

### 测试编写 Agent

测试通过 `config.yaml` 的 `routing.test_writing` 配置，默认使用 `@step-qa`。建议与实现 agent 不同以形成"对抗性"（避免同一 agent 写测试又写实现）。

### 测试生成提示词模板

```
读取 .step/changes/{change}/tasks/{slug}.yaml 中的 scenarios 字段。

为每个场景写一个测试用例，规则：
1. 测试名称必须包含场景 ID，格式: [S-{slug}-xx]
2. 使用 test_type 字段决定测试类型：
   - unit: 可以 mock 外部依赖，但不 mock 被测对象
   - integration: 使用真实依赖
   - e2e: 启动服务，发 HTTP 请求
3. 不写任何实现代码
4. 写完后运行测试，确认全部 FAIL
5. 如果有测试立即通过，说明测试没有验证新行为，需要修改
```

---

## Hook 与 Command 实现（自动化执行）

### `/step/init` 命令

像 `/brainstorm` 和 `/plan` 一样，STEP 通过 opencode 的自定义命令触发：

**命令文件：** `~/.config/opencode/commands/step/init.md`

```markdown
---
description: "初始化 STEP 协议并开始全生命周期开发流程。自动检测项目状态并进入对应阶段。"
---

检查当前项目是否已初始化 STEP 协议（.step/ 目录是否存在）。

如果 .step/ 不存在：
  1. 创建 .step/ 目录结构（config.yaml, baseline.md, decisions.md, state.yaml）
  2. 创建 scripts/gate.sh 和 scripts/scenario-check.sh
  3. 将 state.yaml 的 current_phase 设为 "phase-0-discovery"
  4. 告诉用户："STEP 已初始化。当前阶段: Phase 0 Discovery。请描述你的想法，我们开始讨论。"

如果 .step/ 已存在：
  1. 读取 .step/state.yaml
  2. 根据 current_phase 进入对应阶段
  3. 如果有 current task，显示状态行：
     "📍 Phase X | Change: {name} | Task: {slug} | Status: xxx | Next: xxx"
  4. 从上次中断的位置继续

在所有阶段中遵守以下规则：

Phase 0 (Discovery): 开放式讨论，用户主导方向，LLM 提供分析。不逐个提问。
Phase 1 (PRD): 分段展示 baseline.md 草稿，选择题确认细节。
Phase 2 (Tech Design): 开放式讨论技术方案，LLM 提供对比分析，用户讨论后确定。
Phase 3 (Planning): 生成任务图和场景矩阵，用户审核确认。
Phase 4 (Execution): TDD 循环（测试模型按 config.yaml 配置），gate 验证。
Phase 5 (Review): 独立审查（需求合规 > 代码质量）。

每次对话结束时必须更新 .step/state.yaml。
next_action 必须精确到文件名和具体动作。
不允许违反 baseline.md 约束，冲突时必须新建变更并更新 spec/design。
```

### SessionStart Hook

**Hook 文件：** `~/.config/opencode/hooks/step/hooks.json`

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh"
          }
        ]
      }
    ]
  }
}
```

**Hook 脚本：** `~/.config/opencode/hooks/step/session-start.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

# 查找 .step/state.yaml
STATE_FILE=""
if [ -f ".step/state.yaml" ]; then
  STATE_FILE=".step/state.yaml"
elif [ -f "${OPENCODE_PROJECT_DIR:-.}/.step/state.yaml" ]; then
  STATE_FILE="${OPENCODE_PROJECT_DIR}/.step/state.yaml"
fi

if [ -z "$STATE_FILE" ]; then
  # 没有 STEP 项目，不注入上下文
  cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": ""
  }
}
EOF
  exit 0
fi

# 读取 state.yaml 内容
STATE_CONTENT=$(cat "$STATE_FILE" 2>&1 || echo "Error reading state.yaml")

# 读取当前变更和任务（如果有）
TASK_CONTENT=""
CURRENT_CHANGE=$(grep 'current_change:' "$STATE_FILE" 2>/dev/null | head -1 | sed 's/.*current_change: *//' | tr -d ' "'"'" || true)
CURRENT_TASK=$(grep -E "^\s+current:" "$STATE_FILE" 2>/dev/null | head -1 | sed 's/.*current: *//' | tr -d ' "'"'" || true)
if [ -n "$CURRENT_CHANGE" ] && [ -n "$CURRENT_TASK" ]; then
  TASK_PATH=".step/changes/${CURRENT_CHANGE}/tasks/${CURRENT_TASK}.yaml"
  if [ -f "$TASK_PATH" ]; then
    TASK_CONTENT=$(cat "$TASK_PATH" 2>&1 || echo "")
  fi
fi

# 读取 baseline
BASELINE_CONTENT=""
if [ -f ".step/baseline.md" ]; then
  BASELINE_CONTENT=$(cat ".step/baseline.md" 2>&1 || echo "")
fi

# 转义 JSON
escape_for_json() {
  local input="$1"
  local output=""
  local i char
  for (( i=0; i<${#input}; i++ )); do
    char="${input:$i:1}"
    case "$char" in
      $'\\') output+='\\\\' ;;
      '"') output+='\\"' ;;
      $'\n') output+='\\n' ;;
      $'\r') output+='\\r' ;;
      $'\t') output+='\\t' ;;
      *) output+="$char" ;;
    esac
  done
  printf '%s' "$output"
}

STATE_ESC=$(escape_for_json "$STATE_CONTENT")
TASK_ESC=$(escape_for_json "$TASK_CONTENT")
BASELINE_ESC=$(escape_for_json "$BASELINE_CONTENT")

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "<STEP_PROTOCOL>\\nSTEP 协议已激活。以下是项目当前状态：\\n\\n## state.yaml\\n${STATE_ESC}\\n\\n## 当前任务\\n${TASK_ESC}\\n\\n## Baseline\\n${BASELINE_ESC}\\n\\n## 规则\\n1. 根据 current_phase 进入对应阶段\\n2. Phase 0/2: 开放式讨论，用户主导\\n3. Phase 1/3: 选择题确认细节\\n4. Phase 4: TDD(测试用codex)+Gate\\n5. 对话结束必须更新 state.yaml\\n6. 不违反 baseline 约束\\n7. Gate 失败: 自动修复最多3轮，仍失败标 blocked\\n</STEP_PROTOCOL>"
  }
}
EOF

exit 0
```

### 自动识别流程

```
Session 开始
  │
  ├── Hook 检测 .step/state.yaml 是否存在
  │     │
  │     ├── 存在 → 注入状态到上下文 → LLM 自动恢复到对应阶段
  │     │
  │     └── 不存在 → 不注入（正常 session）
  │
  └── 用户输入 /step/init
        │
        ├── .step/ 不存在 → 初始化 → Phase 0
        │
        └── .step/ 存在 → 读取状态 → 恢复到当前阶段
```

---

## 完整 AGENTS.md 模板

```markdown
使用中文回复

## STEP Protocol（如果 .step/ 目录存在则必须遵守）

### Session 启动
1. 读取 `.step/state.yaml`
2. 读取当前 change 的 spec + 当前 task YAML（如果 Phase 4+）
3. 读取 `.step/baseline.md`
4. 输出状态行: "📍 Phase X | Change: {name} | Task: {slug} | Status: xxx"

### Phase 规则
- Phase 0 (Discovery): 开放式讨论，用户主导，不逐个提问
- Phase 1 (PRD): 分段展示，选择题确认细节
- Phase 2 (Tech Design): 开放式讨论技术方案，确认后选择题定细节
- Phase 3 (Planning): 生成任务图+场景矩阵，用户审核
- Phase 4 (Execution): TDD（测试由 @step-qa 编写，实现按 file_routing）+ Gate 验证
- Phase 5 (Review): 独立审查（需求合规 > 代码质量）

### Execution 规则
- 遵循 established_patterns
- 测试先行: 按 routing.test_writing 派发 @step-qa 写测试 → 确认 FAIL → 再写实现
- 场景 ID: 测试名必须包含 [S-{slug}-xx]
- Gate: `./scripts/gate.sh lite {slug}`（默认增量；Review 前与归档前必须跑 `full --all`）
- Quick 模式：`./scripts/gate.sh quick {slug}`（模型判定小改动时使用）
- 完成判定: 所有 scenario pass + gate pass → 才能标 done

### Gate 失败
- 自动修复最多 3 轮
- 3 轮后仍失败 → 标 blocked + 请求人工介入

### Session 结束
1. 更新 state.yaml（last_updated, progress, next_action）
2. next_action 精确到文件名和具体动作
3. 不允许写"继续开发"

### 防漂移
- 不违反 baseline.md 约束
- 不违反 decisions.md ADR
- 冲突时先新建变更并更新 spec/design
- Post-MVP 变更走 changes/ 流程（遵循完整 STEP）
- Bug 修复走 Hotfix 流程（遵循完整 STEP）

### 归档
- 变更完成后，使用 `/archive` 命令或说 "归档 {change-name}" 归档到 `.step/archive/`
- 归档脚本: `./scripts/step-archive.sh [change-name|--all]`
```

---

## 初始化脚本

初始化逻辑在 `scripts/step-init.sh` 中实现，由 `/step/init` 命令调用。主要功能：

1. **项目检测** — `detect_project()` 扫描 16 种包管理器/清单文件 + 6 种工具目录，判断是已有项目还是绿地项目
2. **创建目录** — `.step/changes/init/tasks/`, `.step/archive/`, `.step/evidence/`, `scripts/`
3. **创建初始变更文档** — `.step/changes/init/findings.md` + `.step/changes/init/spec.md` + `.step/changes/init/design.md`
4. **复制模板** — 从 `templates/` 复制 `config.yaml`, `state.yaml`, `baseline.md`, `decisions.md`, `findings.md`
5. **复制脚本** — 复制 `gate.sh`, `scenario-check.sh`, `step-worktree.sh` 到项目 `scripts/` 目录
6. **已有项目提示** — 检测到已有代码时，提示 LLM 先分析现有代码结构再讨论新需求

详见 `scripts/step-init.sh` 源码。

---

## 保证与限制

### 硬保证（技术层面强制）

| 机制              | 保证内容                     | 原理                                                        |
| ----------------- | ---------------------------- | ----------------------------------------------------------- |
| gate.sh           | lint/typecheck/test 结果准确 | 真实执行命令，退出码决定 pass/fail                          |
| scenario-check.sh | 场景 ID 覆盖率准确           | grep 硬匹配，不依赖 LLM 判断                                |
| Subagent 模型绑定 | 不同角色用不同模型           | agents/*.md frontmatter 默认值 + oh-my-opencode preset 覆盖 |
| SessionStart Hook | 有 .step/ 就注入状态         | bash 脚本，确定性执行                                       |
| step-init.sh      | 文件结构正确                 | 从 templates/ 复制，确定性                                  |

### 软保证（prompt 层面，依赖 LLM 遵守）

| 约束             | 风险             | 缓解措施                                   |
| ---------------- | ---------------- | ------------------------------------------ |
| Phase 流转顺序   | LLM 可能跳过阶段 | Hook 注入 current_phase，SKILL.md 明确规则 |
| TDD 先测试后实现 | LLM 可能先写实现 | Developer agent 约束 + gate 验证测试存在   |
| 每次跑 gate      | LLM 可能跳过     | SKILL.md 硬规则 + Review 阶段检查 evidence |
| baseline 确认    | LLM 可能直接改   | 文档标记确认 + changes/ 流程约束           |
| next_action 恢复 | LLM 可能不遵守   | Hook 注入 state.yaml，包含 next_action     |

### 不能保证（需要外部机制）

| 限制             | 原因                    | 现状                                    |
| ---------------- | ----------------------- | --------------------------------------- |
| 主会话中途切模型 | opencode 启动时选定模型 | 通过 dispatch subagent 间接实现不同模型 |
| 文件写保护       | 文件系统无锁机制        | baseline 确认是契约不是文件锁           |

---

## 自主操作规则

### 不需要用户确认（直接执行）

| 操作                    | 说明                        |
| ----------------------- | --------------------------- |
| git add / commit / push | 常规提交（不含 force push） |
| 文件创建、修改、删除    | 方向已在讨论中达成共识的    |
| 运行测试、lint、build   | gate.sh 及任何验证命令      |
| install.sh --force      | 重装 STEP 插件              |
| 创建目录结构            | .step/ 子目录、scripts/ 等  |

### 需要用户确认

| 操作                      | 原因                       |
| ------------------------- | -------------------------- |
| baseline.md 首版确认      | Phase 1 出口，确认需求基线 |
| 技术方案选择              | 有多个可选方案时需用户决策 |
| 需求变更（新建变更）      | 影响 baseline 范围         |
| git push --force / rebase | 可能丢失他人工作           |
| 删除用户数据或不可逆操作  | 无法撤销                   |

---

## Lite Mode（快速通道）

> 针对小型任务（bug fix、小功能、配置变更等）的简化流程。
> 3 个阶段代替 6 个阶段，保留核心质量保证，去掉重量级仪式。

### 适用场景

Lite Mode 适用于**满足以下全部条件**的任务：
- 影响范围小（≤ 3 个文件）
- 不涉及架构变更
- 不需要新的技术方案评估
- 已有 baseline 存在（不是新项目的第一个任务）

### 触发方式

1. **自动检测**：输入描述短（< 100 字）+ 范围关键词（fix, 修复, 加个, 改下, tweak, patch）+ 无架构关键词（架构, 重构, 迁移, redesign）+ 已有 baseline
2. **显式指定**：`/step/init quick`、`/step/init lite`
3. **强制 Full**：`/step/init full` 或在对话中说"用完整模式"

Quick 模式不使用硬阈值（如文件数或关键词），由模型基于语义判断是否适用；
若执行中发现风险高于预期，必须升级到 lite/full，并记录升级原因。
4. **模式切换**：执行中发现复杂度超预期 → 升级到 Full Mode（反之不行）

### 3 阶段流程

```
L1 Quick Spec          L2 Execution           L3 Review
(合并 Phase 0+1+2)  →  (TDD + Gate)       →  (Code Review)
一次确认即可            测试先行                 需求合规 > 代码质量
```

#### L1: Quick Spec（一次确认，派发 @step-pm via routing.lite_spec）

```
用户: "修复 XXX 的 bug" / "给 YYY 加个 ZZZ 功能"

LLM 输出（一次性，不分段）:
  📋 Lite Task: fix-empty-password
  ├── 目标: 一句话
  ├── 影响文件: [file1, file2]
  ├── BDD 场景:
  │   ├── S-fix-empty-password-01: happy path
  │   ├── S-fix-empty-password-02: edge case
  │   └── S-fix-empty-password-03: error case
  ├── 不做: [明确排除项]
  └── 验证: gate lite

用户: "可以" / 修改后确认

→ 写入 .step/changes/{change}/tasks/fix-empty-password.yaml
→ 进入 L2

批量任务处理（用户一次提交多个小任务时）:

用户: "1) 修复空密码 2) 调整按钮位置 3) 加载动画"

LLM 输出（批量展示，一次确认）:
  📋 Lite Batch (3 tasks)
  ├── fix-empty-password: 修复空密码     → 2 场景
  ├── adjust-button-position: 调整按钮位置   → 2 场景
  └── add-loading-animation: 加载动画       → 3 场景

  全部确认？

用户: "可以"

→ 写入 3 个 YAML 到 .step/changes/{change}/tasks/
→ L2 逐个执行（每个任务独立 TDD + gate + commit）
→ 其中某个发现复杂度超预期 → 仅该任务升级 Full Mode，其他继续 Lite
```

**与 Full Mode 的区别：**
- 不创建 baseline.md（复用已有的）
- 不做技术方案对比
- 不分段确认（一次全部确认）
- 不记录 ADR（除非涉及新决策）

#### L2: Execution（TDD + Gate）

```
Step 1: 写测试 → 确认全部 FAIL (TDD RED)
Step 2: 写实现 → 测试通过 (TDD GREEN)
Step 3: Gate → gate.sh lite {slug}（默认增量）
Step 3.5: Review 前强制全量回归 → gate.sh full {slug} --all
         lint + typecheck + test + scenario
```

**核心保留：**
- ✅ TDD（先测试后实现）— 必须
- ✅ BDD 场景 100% 覆盖 — 必须
- ✅ 场景 ID 绑定 (`[S-{slug}-xx]`) — 必须
- ✅ Code Review — 必须（与 Full Mode 相同）

**简化项：**
- ⏭️ e2e 测试按需（不强制）
- ⏭️ 不修改 baseline 需求定义/约束（允许完成标记 [ ] → [x]）
- ⏭️ 不记录 ADR（除非新决策）

#### L2 + L3 自主执行（无需用户确认）

L1 用户确认方案后，L2（开发+测试+gate）和 L3（review+commit）**全程自主执行**，不再打断用户确认。

#### L3: Review（Code Review + Commit）

与 Full Mode Phase 5 相同的 Review 流程，保证代码质量：

```
Gate lite 通过后执行:
  1. Code Review（按 Phase 5 规则）
     - 第一优先级: 需求合规
       □ baseline 约束未违反
       □ BDD 场景 100% 覆盖
       □ lite task spec 全部满足
     - 第二优先级: 代码质量
       □ SOLID + 安全 + 性能 + 边界条件
  2. Review 通过 → Commit
     提交信息含 task slug
     例: "fix(auth): fix-empty-password 修复空密码验证 [3/3 S]"
  3. Review 不通过 → 修复 → 重新 Gate → 重新 Review
  4. 更新 state.yaml + baseline.md 对应项标记 [x]
```

**Lite 精简的是规划阶段（L1 一次确认），不是质量保证阶段。**

#### 完成后：Check + 归档提示

L3 commit 完成后，**提示用户 check 结果，并询问是否归档**：

```
LLM: "✅ 已完成并提交。请 check 以下变更：
      - [变更摘要]
      是否归档此任务？"

用户响应:
  ├── "没问题，归档" → 执行归档 → 任务结束
  ├── "没问题，合并并归档"（worktree 模式）
  │      → 合并主分支 → 归档 change → 输出冲突及解决方案 → 清理 worktree
  ├── "没问题，不归档" → 任务保持 done，留在 tasks/ → 结束
  └── "这里要改一下..." / "还需要加个..."
        → 不新建 task（在当前 task 上继续迭代）
        → task status 回退到 in_progress
        → 根据反馈修改 → gate → review → commit
        → 再次提示 check + 归档
```

**关键规则：用户反馈修改意见时，不新建 task。在当前 task 基础上继续迭代，直到用户满意。**

### Worktree 自动流程（可选）

当 `.step/config.yaml` 中 `worktree.enabled=true` 时：

1. 变更开始阶段自动创建 worktree：`./scripts/step-worktree.sh create {change-name}`
2. Commit 后询问用户是否“合并回主分支并归档”
3. 用户确认后执行 `./scripts/step-worktree.sh finalize {change-name}`：
   - 先合并到“创建该 worktree 时所在分支”
   - 再归档 change
   - 若冲突，统一交由大模型解冲突（禁止直接 ours/theirs 丢弃代码）
   - 生成 `.step/conflict-report.md`，并在回复用户时说明：冲突文件、保留/舍弃逻辑及原因、验证结果
   - 合并完成后清理 feature worktree
4. 若用户拒绝合并，保留当前分支和 worktree，稍后可手动触发 finalize

### Lite Task YAML 格式

```yaml
# .step/changes/{change}/tasks/fix-empty-password.yaml
id: fix-empty-password
title: "修复空密码未报错"
mode: lite
status: planned  # planned | in_progress | done
created: "2026-02-15"
parent_baseline: ".step/baseline.md"  # 关联已有 baseline

goal: "POST /api/register 空密码返回 400"
non_goal:
  - "不修改其他验证逻辑"

affected_files:
  - "src/auth/register.ts"
  - "test/auth/register.test.ts"

scenarios:
  - id: S-fix-empty-password-01
    given: "password 为空字符串"
    when: "POST /api/register"
    then: "返回 400 + { error: 'password required' }"
    test_file: "test/auth/register.test.ts"
    test_name: "[S-fix-empty-password-01] 空密码返回 400"
    test_type: unit
    status: not_run

  - id: S-fix-empty-password-02
    given: "password 为 null"
    when: "POST /api/register"
    then: "返回 400"
    test_file: "test/auth/register.test.ts"
    test_name: "[S-fix-empty-password-02] null 密码返回 400"
    test_type: unit
    status: not_run

done_when:
  - "gate.sh lite fix-empty-password"
```

### 变更归档

`.step/changes/` 存放所有活跃变更，`.step/archive/` 存放已完成变更。变更完成后整个文件夹归档。

**归档触发方式（三选一）：**

1. **变更所有任务完成后提示**：当变更下所有 tasks 的 status 都为 done 时，LLM 主动提示：
   > "变更已完成。是否要归档？可以说「归档」或 `/archive`"
2. **自然语言**：用户说 "归档" 或 "归档 init"
3. **命令**：`/archive`、`/archive {change-name}`

**归档操作：**

```
# 归档指定变更（整个文件夹移入 archive/）
mv .step/changes/init/ .step/archive/2026-02-15-init/

# 归档后更新
→ baseline.md 反映最新状态
→ state.yaml current_change 清空（如果归档的是当前变更）
```

**归档规则：**
- 变更下所有任务 status 为 done 且 gate 通过 且 Review 通过才可归档
- 归档脚本自动检查 `status: done`，未完成的自动跳过
- 文件名加日期前缀便于按时间查找
- 归档不是删除，仍可 grep 搜索历史决策
- 归档是手动/提示触发的清理操作，不自动执行

### Lite vs Full 对比

| 维度        | Full Mode       | Lite Mode  |
| ----------- | --------------- | ---------- |
| 阶段数      | 6 (Phase 0-5)   | 3 (L1-L3)  |
| 确认轮数    | 多次分段确认    | 一次确认   |
| Baseline    | 创建 + 确认     | 复用已有   |
| ADR         | 必须记录        | 按需       |
| TDD         | ✅ 必须          | ✅ 必须     |
| BDD 覆盖    | ✅ 100%          | ✅ 100%     |
| Gate        | lite / full | lite   |
| e2e 测试    | ✅ 必须          | 按需       |
| Code Review | ✅ 完整审查      | ✅ 完整审查 |
| 预计时间    | 65-110 min      | 10-15 min  |

### 模式升级

如果 L2 执行中发现：
- 影响文件 > 3 个
- 需要新的架构决策
- 发现关联 bug 需要修复

→ **必须升级到 Full Mode**：
1. 将 lite task YAML 的 `mode` 字段改为 `full`，补充完整场景矩阵
2. 补充 baseline 更新（如需要）
3. 从 Phase 3 开始补完场景矩阵
4. 后续按 Full Mode 执行

---

## 9 个反馈逐一对应

| #   | 反馈                                         | 本文档如何处理                                                                              |
| --- | -------------------------------------------- | ------------------------------------------------------------------------------------------- |
| 1   | Phase 0/2 应该是开放式讨论                   | Phase 0/2 改为"用户主导的开放式讨论"，Phase 1/3 才用选择题确认细节                          |
| 2   | Post-MVP 变更和 bug 修复                     | 新增"Post-MVP"章节：统一变更目录（spec + design + tasks）覆盖新增功能、Hotfix、约束变更      |
| 3   | 场景规则是 BDD                               | 场景 = BDD Given/When/Then = 行为规格。测试类型由 test_type 字段指定                        |
| 4   | 用 hook 保证规则生效                         | 新增 SessionStart hook（自动注入 state.yaml 到上下文）+ `/step/init` 命令                   |
| 5   | 统一使用 opencode，删除 tool                 | config.yaml 改为 routing（agent 路由）+ file_routing（文件分流）+ gate（命令）              |
| 6   | review 模型可选，规则参考 code-review-expert | 创建 step-reviewer agent，参考 code-review-expert 实现。需求合规为第一优先级                |
| 7   | gate 失败如何处理                            | 新增"Gate 失败处理流程"：Opus/Codex xhigh 先分析根因 → 分类修复最多 3 轮 → 仍失败标 blocked |
| 8   | 初始化做成 /step 命令                        | 创建 `commands/step/init.md`，检测 .step/ 是否存在：不存在则初始化，存在则恢复              |
| 9   | 测试代码模型可配置                           | routing.test_writing 配置测试编写 agent（默认 @step-qa），与实现 agent 不同形成对抗性       |
### `/step/status` 命令

用于快速查看：
- 当前 phase/change/task
- 任务完成度（Done/Total）
- gate evidence 状态（PASS/FAIL）
- 当前阻塞项（known_issues）
