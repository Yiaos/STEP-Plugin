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
  Hotfix → Change Request → 回到 Phase 4
```

### 对话模式说明

STEP 使用两种对话模式，在不同阶段切换：

| 模式 | 适用阶段 | 特征 |
|------|----------|------|
| **开放式讨论** | Phase 0 Discovery, Phase 2 Tech Design | 用户主导提问方向，LLM 提供信息和分析供讨论，不主动逐个提问 |
| **选择题确认** | Phase 1 PRD 细节, Phase 3 Plan 细节 | LLM 提供结构化选项，逐项确认细节 |

**关键区别：** Phase 0 和 Phase 2 是用户探索式的，用户提出问题、LLM 回答分析。不是 LLM 每次问一个问题等用户回答。

### 角色与 Agent 映射

STEP 定义 4 个角色，每个角色对应一个自定义 agent 定义文件（`STEP/agents/`），在对应阶段自动切换思维模式：

| 角色 | Agent 文件 | 模型 | 适用阶段 | 思维模式 |
|------|-----------|------|----------|----------|
| PM（产品经理） | `agents/pm.md` | claude-opus | Phase 0 Discovery, Phase 1 PRD | 用户视角、需求优先级、验收标准 |
| Architect（架构师） | `agents/architect.md` | claude-opus | Phase 2 Tech Design, Phase 3 Plan | 技术权衡、系统设计、任务拆分 |
| QA（质量工程师） | `agents/qa.md` | claude-sonnet-thinking | Phase 3 场景补充, Phase 4 Gate 分析, Phase 5 Review | 对抗性测试思维、根因分析、需求合规 |
| Developer（开发者） | `agents/developer.md` | codex | Phase 4 Execution | TDD 实现、遵循 patterns、不越界 |

**角色切换原则：**
- 每个 Phase 有默认角色，通过 dispatch 对应 agent 实现
- PM 和 Architect 使用高推理模型（规划需要深度思考）
- QA 使用 thinking 模型（对抗性分析需要深度推理）
- Developer 使用代码模型（执行需要代码生成能力）
- 角色之间形成制衡：PM 定义"做什么"、Architect 定义"怎么做"、QA 定义"怎么破坏它"、Developer 只做被定义的事

### 文件结构

```
.step/
├── config.yaml               # 项目配置（模型路由、gate 命令）
├── baseline.md                # Phase 1 输出：冻结需求
├── tech-comparison.md         # Phase 2 输出：技术方案对比
├── decisions.md               # Phase 2 输出：架构决策日志
├── state.yaml                 # Phase 3+ 持续更新：项目状态机
├── tasks/
│   ├── T-001.yaml             # 任务定义 + 场景矩阵
│   └── ...
├── change-requests/
│   └── CR-001.yaml            # 变更请求
└── evidence/
    ├── T-001-gate.json        # gate 运行结果
    └── T-001-scenario.json    # 场景覆盖结果
scripts/
├── gate.sh                    # 质量门禁
└── scenario-check.sh          # 场景覆盖检查
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
- 冻结时间: YYYY-MM-DD
- 修改方式: 必须通过 Change Request
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

LLM: → 写入 .step/tech-comparison.md + .step/decisions.md
```

### 输出物

- `.step/tech-comparison.md`：方案对比表
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
id: T-003
title: "用户注册 API"
status: planned  # planned | ready | in_progress | blocked | done
depends_on: [T-002]
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
    - id: S-003-01
      given: "email=test@x.com, password=Valid123!"
      when: "POST /api/register"
      then: "返回 201 + { data: { id, email } }"
      test_file: "test/auth/register.test.ts"
      test_name: "[S-003-01] 正常注册成功"
      test_type: unit  # unit | integration | e2e
      status: not_run

  edge_cases:
    - id: S-003-02
      given: "email 已被注册"
      when: "POST /api/register"
      then: "返回 409"
      test_file: "test/auth/register.test.ts"
      test_name: "[S-003-02] 重复邮箱注册"
      test_type: unit
      status: not_run

    - id: S-003-03
      given: "password 少于 8 位"
      when: "POST /api/register"
      then: "返回 400"
      test_file: "test/auth/register.test.ts"
      test_name: "[S-003-03] 密码太短"
      test_type: unit
      status: not_run

  error_handling:
    - id: S-003-04
      given: "数据库连接失败"
      when: "POST /api/register"
      then: "返回 503"
      test_file: "test/auth/register.test.ts"
      test_name: "[S-003-04] 数据库不可用"
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

---

## Phase 4: Execution（TDD + Gate）

**多模型编排：** 所有工具统一使用 opencode，通过 opencode 的模型配置切换底层模型。

### 模型路由

```yaml
# .step/config.yaml
model_routing:
  # Phase 0-3: 规划阶段
  discovery: { model: "claude-opus" }
  prd: { model: "claude-opus" }
  tech_design: { model: "claude-opus" }
  planning: { model: "claude-opus" }

  # Phase 4: 执行阶段
  test_writing: { model: "codex", note: "可配置，建议与实现模型不同以形成对抗性" }
  frontend: { model: "gemini", patterns: ["src/components/**", "**/*.tsx", "**/*.css"] }
  backend: { model: "codex", patterns: ["src/api/**", "src/db/**", "src/lib/**"] }
  complex_logic: { model: "claude-opus", note: "手动指定" }

  # Phase 5: 审查阶段
  review: { model: "claude-opus | codex", note: "可选，参考 code-review-expert skill" }

gate:
  lint: "pnpm lint --no-error-on-unmatched-pattern"
  typecheck: "pnpm tsc --noEmit"
  test: "pnpm vitest run"
  build: "pnpm build"
```

### 执行循环

```
Step 1: 加载上下文
  读 state.yaml → 读 task YAML → 读 baseline.md
  输出: "📍 T-003 用户注册 | 4 场景待实现"

Step 2: 写测试（使用 config.yaml 中 test_writing 指定的模型）
  ┌────────────────────────────────────────────────┐
  │ 读取 .step/tasks/T-003.yaml 的场景矩阵          │
  │ 为每个场景写测试，名称包含 [S-xxx-xx]              │
  │ 不写任何实现代码                                  │
  │ 跑测试确认全部 FAIL                               │
  │ 建议：测试与实现用不同模型以形成对抗性              │
  └────────────────────────────────────────────────┘
  → 确认全部 FAIL（TDD RED）

Step 3: 写实现（按类型选模型）
  前端代码 → gemini
  后端代码 → codex
  复杂逻辑 → claude-opus
  → 每实现一个场景，跑 gate quick

Step 4: Gate 验证
  ./scripts/gate.sh standard T-003
  → 包含场景覆盖检查（scenario-check.sh）
  → 通过 → Step 5
  → 失败 → Gate 失败处理流程（见下方）

Step 5: Review + Commit（每完成一个任务都执行）
  ┌────────────────────────────────────────────────┐
  │ Gate 通过后，立即执行 Review + Commit:           │
  │                                                │
  │ 1. Review（按 Phase 5 规则）                     │
  │    - 第一优先级: 需求合规                        │
  │      对照 baseline → PRD → BDD 场景 → ADR       │
  │    - 第二优先级: 代码质量                        │
  │      SOLID + 安全 + 性能 + 边界条件              │
  │                                                │
  │ 2. Review 通过 → Commit                         │
  │    git add + commit（提交信息包含 task ID）       │
  │    例: "feat(auth): T-003 用户注册 API [4/4 S]"  │
  │                                                │
  │ 3. Review 不通过 → 修复 → 重新 Gate → 重新 Review│
  └────────────────────────────────────────────────┘

Step 6: 更新状态
  Review 通过 + Committed → status: done
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
    3. fix_strategy: "具体修复策略"
    4. affected_files: ["file:line", ...]
    5. risk: "修复可能影响的其他模块"
```

**为什么要用强模型分析：** 直接让执行 agent 看到报错就改，容易改表面不改根因，导致反复失败。先分析再修，一次修对的概率显著更高。

### 阶段 2: 分级修复

基于分析结果，按类别处理：

```
Gate 分级修复
  │
  ├── lint 失败
  │     → 自动修复: 按分析结果修复 → 重跑 gate quick
  │     → 通常不需要人工干预
  │
  ├── typecheck 失败
  │     → 按分析结果修复 → 重跑 gate quick
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

### Review 优先级：需求合规 > 代码质量

Review 的**首要职责**是验证"做的东西对不对"（需求合规），其次才是"代码写得好不好"（代码质量）。

**审查步骤（固定流程，按优先级排序）：**

```
═══════════════════════════════════════
  第一优先级：需求合规（MUST，不通过则阻断）
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

═══════════════════════════════════════
  第二优先级：代码质量（参考 code-review-expert）
═══════════════════════════════════════

6. SOLID + Architecture Smells
   □ SRP: 模块职责是否单一？
   □ OCP: 是否通过扩展而非修改来增加行为？
   □ LSP: 子类是否满足基类契约？
   □ ISP: 接口是否最小化？
   □ DIP: 高层是否依赖抽象？

7. Security & Reliability
   □ XSS、注入（SQL/NoSQL/命令）、SSRF、路径穿越
   □ AuthZ/AuthN 缺口、多租户隔离
   □ 密钥泄露、日志中的敏感信息
   □ 竞态条件、TOCTOU、缺少锁

8. Code Quality
   □ 错误处理：吞异常、过宽 catch、缺失错误处理
   □ 性能：N+1 查询、热路径计算密集、缺失缓存
   □ 边界条件：null/undefined、空集合、数值边界、off-by-one
```

**严重程度分级（参考 code-review-expert）：**

| 级别 | 名称 | 描述 | 行动 |
|------|------|------|------|
| P0 | Critical | 需求不合规、安全漏洞、数据丢失 | 必须阻断 |
| P1 | High | 场景缺失、逻辑错误、SOLID 严重违反 | 合并前修复 |
| P2 | Medium | 代码异味、可维护性、轻微 SOLID 违反 | 本轮或后续修复 |
| P3 | Low | 风格、命名、小建议 | 可选改进 |

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
```

### Review 模型选择

用户可根据需要选择任何模型执行上述审查框架：

```
选项 A: claude-opus → 深度审查，擅长 spec compliance 和架构分析
选项 B: codex       → 快速审查，擅长代码模式扫描
选项 C: 两阶段组合   → codex 快速扫描 + opus 深度分析
```

---

## Post-MVP: Change Request 与 Hotfix 流程

MVP 完成后不是终点。后续的需求变更、bug 修复**同样遵循 STEP 协议**，所有过程记录在 `.step/` 下。

### 核心原则

Post-MVP 的每一次变更都必须：
1. **有记录** — CR / Hotfix 任务 YAML 写入 `.step/`
2. **有场景** — 新增/修改的行为必须有 BDD 场景矩阵
3. **有验证** — 走 gate（hotfix 必须 gate full 回归）
4. **有审查** — Review + Commit，与 MVP 执行阶段相同

### 场景 1: 需求变更（新功能 / 修改行为）

```
用户: "MVP 用起来不错，但需要加一个 XX 功能"
  │
  ├── 1. 创建 Change Request
  │     .step/change-requests/2026-02-14-CR-001.yaml:
  │       id: 2026-02-14-CR-001
  │       type: feature  # feature | behavior_change | constraint_change
  │       description: "新增 XX 功能"
  │       impacts:
  │         - baseline: "MVP Scope 新增 F-7"
  │         - tasks: "需要新增 T-008"
  │         - existing_code: "需要修改 src/api/xxx.ts"
  │       decision: pending
  │
  ├── 2. 用户审批
  │     decision: approved / rejected
  │
  ├── 3. 如果 approved:
  │     → 更新 baseline.md（追加 F-7）
  │     → 创建新 task T-008.yaml（含完整场景矩阵）
  │     → 更新 state.yaml upcoming
  │     → 进入 Phase 4 执行 T-008（完整 TDD + Gate + Review + Commit）
  │     → 更新 state.yaml（记录 2026-02-14-CR-001 已完成）
  │
  └── 4. 如果 rejected:
        → CR 状态标 rejected，归档
```

### 场景 2: Bug 修复（Hotfix）

```
用户: "注册时空密码没报错"
  │
  ├── 1. 定位问题
  │     → 读 state.yaml 找到对应任务（T-003）
  │     → 读 task YAML 找到对应场景（S-003-03 密码太短）
  │     → 检查场景 status（如果是 pass → 测试没覆盖到这个 case）
  │
  ├── 2. 创建 Hotfix 任务（记录在 .step/tasks/）
  │     .step/tasks/2026-02-14-T-003-hotfix-001.yaml:
  │       id: 2026-02-14-T-003-hotfix-001
  │       type: hotfix
  │       parent_task: T-003
  │       bug_description: "空密码未返回 400"
  │       root_cause: "zod schema 未校验空字符串"
  │       scenarios:
  │         - id: S-003-HF01
  │           given: "password 为空字符串"
  │           when: "POST /api/register"
  │           then: "返回 400"
  │           test_type: unit
  │           status: not_run
  │
  ├── 3. TDD 修复（完整 Phase 4 流程）
  │     → 先写失败测试（按 config.yaml test_writing 模型）
  │     → 修复代码
  │     → gate standard → Review + Commit
  │
  └── 4. 回归验证
        → gate full（确保不破坏其他功能）
        → 更新 state.yaml（known_issues 移除已修复项，tasks.completed 追加 2026-02-14-T-003-hotfix-001）
```

### 场景 3: 约束变更（影响大）

```
用户: "我们需要把 cookie session 改成 JWT"
  │
  ├── 1. 创建高影响 CR
  │     .step/change-requests/2026-02-14-CR-002.yaml:
  │       type: constraint_change
  │       conflicts_with:
  │         - "baseline.md C-3: 使用 cookie session"
  │         - "ADR-003: 选择 cookie 的理由"
  │       impact_scope:
  │         - "T-003, T-004, T-005 全部受影响"
  │         - "auth middleware 全量重写"
  │
  ├── 2. 影响分析
  │     LLM 分析哪些已完成任务需要修改
  │     列出所有受影响文件和测试
  │
  ├── 3. 用户确认
  │     → approved → 更新 baseline + decisions + 受影响 task
  │     → 创建迁移任务 .step/tasks/2026-02-14-T-MIGRATE-001.yaml（含场景矩阵）
  │
  └── 4. 执行迁移（完整 Phase 4 流程）
        → TDD + gate full + Review + Commit
        → 更新 state.yaml（记录迁移完成）
```

---

## 场景覆盖验证机制

### scenario-check.sh 工作原理

```
任务 YAML 定义:  id: S-003-01
        ↓ 约定
测试文件中写:   it('[S-003-01] 正常注册', ...)
        ↓ grep 匹配
scenario-check.sh: grep "\[S-003-01\]" test/auth/register.test.ts
        ↓
匹配到 → covered    匹配不到 → FAIL
```

gate.sh 在 standard 级别自动调用 scenario-check.sh。

## 测试代码生成策略

### 四层分离（解决"自己出题自己答"问题）

```
Layer 1: 场景定义    ← Phase 3 Architect（happy_path）+ QA（edge/error/security）
Layer 2: 测试代码    ← Phase 4 Developer（按 config.yaml test_writing 模型）
Layer 3: 实现代码    ← Phase 4 Developer（按类型选模型）
Layer 4: 独立审查    ← Phase 5 QA（需求合规 + 代码质量）
```

### 测试模型选择原则

测试模型通过 `config.yaml` 的 `test_writing.model` 配置，建议与实现模型不同以形成"对抗性"（避免同一模型写测试又写实现）。

### 测试生成提示词模板

```
读取 .step/tasks/{task_id}.yaml 中的 scenarios 字段。

为每个场景写一个测试用例，规则：
1. 测试名称必须包含场景 ID，格式: [S-xxx-xx]
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

### `/step` 命令

像 `/brainstorm` 和 `/plan` 一样，STEP 通过 opencode 的自定义命令触发：

**命令文件：** `~/.config/opencode/commands/step/step.md`

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
     "📍 Phase X | Task: T-xxx | Status: xxx | Next: xxx"
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
不允许违反 baseline.md 约束，冲突时走 Change Request。
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

# 读取当前任务（如果有）
TASK_CONTENT=""
CURRENT_TASK=$(grep "id:" "$STATE_FILE" 2>/dev/null | head -1 | sed 's/.*id: //' | tr -d ' ' || true)
if [ -n "$CURRENT_TASK" ] && [ -f ".step/tasks/${CURRENT_TASK}.yaml" ]; then
  TASK_CONTENT=$(cat ".step/tasks/${CURRENT_TASK}.yaml" 2>&1 || echo "")
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
  └── 用户输入 /step
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
2. 读取当前 task YAML（如果 Phase 4+）
3. 读取 `.step/baseline.md`
4. 输出状态行: "📍 Phase X | Task: T-xxx | Status: xxx"

### Phase 规则
- Phase 0 (Discovery): 开放式讨论，用户主导，不逐个提问
- Phase 1 (PRD): 分段展示，选择题确认细节
- Phase 2 (Tech Design): 开放式讨论技术方案，确认后选择题定细节
- Phase 3 (Planning): 生成任务图+场景矩阵，用户审核
- Phase 4 (Execution): TDD（测试模型按 config.yaml 配置）+ Gate 验证
- Phase 5 (Review): 独立审查（需求合规 > 代码质量）

### Execution 规则
- 遵循 established_patterns
- 测试先行: 按 config.yaml test_writing 模型写测试 → 确认 FAIL → 再写实现
- 场景 ID: 测试名必须包含 [S-xxx-xx]
- Gate: `./scripts/gate.sh standard T-xxx`
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
- 冲突时先写 Change Request
- Post-MVP 变更走 CR 流程（遵循完整 STEP）
- Bug 修复走 Hotfix 流程（遵循完整 STEP）
```

---

## 初始化脚本（`/step` 命令内部调用）

```bash
#!/bin/bash
# step-init.sh — 初始化 STEP 协议

set -e

echo "📦 Initializing STEP protocol..."

mkdir -p .step/tasks .step/change-requests .step/evidence scripts

# config.yaml
cat > .step/config.yaml << 'EOF'
model_routing:
  discovery: { model: "claude-opus" }
  prd: { model: "claude-opus" }
  tech_design: { model: "claude-opus" }
  planning: { model: "claude-opus" }
  test_writing: { model: "codex", note: "可配置，建议与实现模型不同" }
  frontend: { model: "gemini", patterns: ["src/components/**", "**/*.tsx", "**/*.css"] }
  backend: { model: "codex", patterns: ["src/api/**", "src/db/**", "src/lib/**"] }
  complex_logic: { model: "claude-opus" }
  review: { model: "claude-opus | codex" }

gate:
  lint: "pnpm lint --no-error-on-unmatched-pattern"
  typecheck: "pnpm tsc --noEmit"
  test: "pnpm vitest run"
  build: "pnpm build"
EOF

# state.yaml
cat > .step/state.yaml << 'EOF'
project: "TODO"
current_phase: "phase-0-discovery"
last_updated: ""
last_agent: ""
last_session_summary: ""
established_patterns: {}
tasks:
  completed: []
  current: null
  upcoming: []
known_issues: []
constraints_quick_ref: []
EOF

# baseline.md
cat > .step/baseline.md << 'EOF'
# Baseline
> 状态: 未冻结（等待 Phase 1 完成）
EOF

# decisions.md
cat > .step/decisions.md << 'EOF'
# Architecture Decision Log
> 等待 Phase 2 完成
EOF

# gate.sh
cat > scripts/gate.sh << 'GATE'
#!/bin/bash
set -e
LEVEL=${1:-standard}
TASK_ID=${2:-""}
PASS=true

run_check() {
  local name=$1; local cmd=$2
  echo "--- $name ---"
  if eval "$cmd" 2>&1; then
    echo "  ✅ $name: PASS"
  else
    echo "  ❌ $name: FAIL"
    PASS=false
  fi
}

echo "🚧 Gate (level: $LEVEL, task: ${TASK_ID:-all})"
run_check "lint" "pnpm lint --no-error-on-unmatched-pattern"
run_check "typecheck" "pnpm tsc --noEmit"

if [ "$LEVEL" != "quick" ]; then
  run_check "unit-test" "pnpm vitest run"
fi

if [ "$LEVEL" != "quick" ] && [ -n "$TASK_ID" ]; then
  run_check "scenario" "./scripts/scenario-check.sh $TASK_ID"
fi

if [ "$LEVEL" = "full" ]; then
  run_check "build" "pnpm build"
fi

if [ "$PASS" = true ]; then
  echo "✅ Gate PASSED"
  exit 0
else
  echo "❌ Gate FAILED"
  exit 1
fi
GATE
chmod +x scripts/gate.sh

# scenario-check.sh
cat > scripts/scenario-check.sh << 'SCENARIO'
#!/bin/bash
set -e
TASK_ID=$1
TASK_FILE=".step/tasks/${TASK_ID}.yaml"

[ ! -f "$TASK_FILE" ] && echo "❌ Not found: $TASK_FILE" && exit 1

echo "🔍 Checking scenario coverage for $TASK_ID..."

TOTAL=0; COVERED=0; MISSING=""
CURRENT_SID=""

while IFS= read -r line; do
  if echo "$line" | grep -qE "^\s+- id: S-"; then
    CURRENT_SID=$(echo "$line" | sed 's/.*id: //' | tr -d ' ')
    TOTAL=$((TOTAL + 1))
  fi
  if echo "$line" | grep -q "test_file:" && [ -n "$CURRENT_SID" ]; then
    TF=$(echo "$line" | sed 's/.*test_file: //' | tr -d '"'"'" | tr -d ' ')
    if [ -f "$TF" ] && grep -q "\[${CURRENT_SID}\]" "$TF"; then
      COVERED=$((COVERED + 1))
    else
      MISSING="${MISSING}\n  ❌ ${CURRENT_SID} not found in ${TF}"
    fi
    CURRENT_SID=""
  fi
done < "$TASK_FILE"

[ $TOTAL -gt 0 ] && COV=$((COVERED * 100 / TOTAL)) || COV=0
echo "📊 Coverage: ${COVERED}/${TOTAL} (${COV}%)"
[ -n "$MISSING" ] && echo -e "\nMissing:${MISSING}"
[ $COV -eq 100 ] && echo "✅ PASS" && exit 0
echo "❌ FAIL (need 100%)" && exit 1
SCENARIO
chmod +x scripts/scenario-check.sh

echo ""
echo "✅ STEP initialized!"
echo "   当前阶段: Phase 0 Discovery"
echo "   请描述你的想法，我们开始讨论。"
```

---

## 保证与限制

### 硬保证（技术层面强制）

| 机制 | 保证内容 | 原理 |
|------|----------|------|
| gate.sh | lint/typecheck/test 结果准确 | 真实执行命令，退出码决定 pass/fail |
| scenario-check.sh | 场景 ID 覆盖率准确 | grep 硬匹配，不依赖 LLM 判断 |
| Subagent 模型绑定 | 不同角色用不同模型 | agents/*.md 定义 + oh-my-opencode 配置 |
| SessionStart Hook | 有 .step/ 就注入状态 | bash 脚本，确定性执行 |
| step-init.sh | 文件结构正确 | 从 templates/ 复制，确定性 |

### 软保证（prompt 层面，依赖 LLM 遵守）

| 约束 | 风险 | 缓解措施 |
|------|------|----------|
| Phase 流转顺序 | LLM 可能跳过阶段 | Hook 注入 current_phase，SKILL.md 明确规则 |
| TDD 先测试后实现 | LLM 可能先写实现 | Developer agent 约束 + gate 验证测试存在 |
| 每次跑 gate | LLM 可能跳过 | SKILL.md 硬规则 + Review 阶段检查 evidence |
| baseline 冻结 | LLM 可能直接改 | 文档标记冻结 + CR 流程约束 |
| next_action 恢复 | LLM 可能不遵守 | Hook 注入 state.yaml，包含 next_action |

### 不能保证（需要外部机制）

| 限制 | 原因 | 现状 |
|------|------|------|
| 主会话中途切模型 | opencode 启动时选定模型 | 通过 dispatch subagent 间接实现不同模型 |
| 文件写保护 | 文件系统无锁机制 | baseline 冻结是契约不是文件锁 |

---

## 自主操作规则

### 不需要用户确认（直接执行）

| 操作 | 说明 |
|------|------|
| git add / commit / push | 常规提交（不含 force push） |
| 文件创建、修改、删除 | 方向已在讨论中达成共识的 |
| 运行测试、lint、build | gate.sh 及任何验证命令 |
| install.sh --force | 重装 STEP 插件 |
| 创建目录结构 | .step/ 子目录、scripts/ 等 |

### 需要用户确认

| 操作 | 原因 |
|------|------|
| baseline.md 冻结 | Phase 1 出口，不可逆契约 |
| 技术方案选择 | 有多个可选方案时需用户决策 |
| 需求变更（CR） | 影响 baseline 范围 |
| git push --force / rebase | 可能丢失他人工作 |
| 删除用户数据或不可逆操作 | 无法撤销 |

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
2. **显式指定**：`/step lite` 或在对话中说"用 lite 模式"
3. **强制 Full**：`/step full` 或在对话中说"用完整模式"
4. **模式切换**：执行中发现复杂度超预期 → 升级到 Full Mode（反之不行）

### 3 阶段流程

```
L1 Quick Spec          L2 Execution           L3 Quick Review
(合并 Phase 0+1+2)  →  (TDD + gate lite)  →  (自动化验证)
一次确认即可            测试先行                 无需人工审查
```

#### L1: Quick Spec（一次确认）

```
用户: "修复 XXX 的 bug" / "给 YYY 加个 ZZZ 功能"

LLM 输出（一次性，不分段）:
  📋 Lite Task L-{seq}
  ├── 目标: 一句话
  ├── 影响文件: [file1, file2]
  ├── BDD 场景:
  │   ├── S-L{seq}-01: happy path
  │   ├── S-L{seq}-02: edge case
  │   └── S-L{seq}-03: error case
  ├── 不做: [明确排除项]
  └── 验证: gate lite

用户: "可以" / 修改后确认

→ 写入 .step/lite/L-{seq}.yaml
→ 进入 L2
```

**与 Full Mode 的区别：**
- 不创建 baseline.md（复用已有的）
- 不做技术方案对比
- 不分段确认（一次全部确认）
- 不记录 ADR（除非涉及新决策）

#### L2: Execution（TDD + Gate Lite）

```
Step 1: 写测试 → 确认全部 FAIL (TDD RED)
Step 2: 写实现 → 测试通过 (TDD GREEN)
Step 3: Gate Lite → gate.sh lite L-{seq}
         lint + typecheck + test + scenario (跳过 build)
```

**核心保留：**
- ✅ TDD（先测试后实现）— 必须
- ✅ BDD 场景 100% 覆盖 — 必须
- ✅ 场景 ID 绑定 (`[S-Lxxx-xx]`) — 必须

**简化项：**
- ⏭️ 跳过 build（gate lite 不含 build）
- ⏭️ e2e 测试按需（不强制）
- ⏭️ 不冻结 baseline
- ⏭️ 不记录 ADR（除非新决策）

#### L3: Quick Review（自动化）

```
Gate lite 通过后自动执行:
  1. 检查: 场景覆盖 100%
  2. 检查: 无 P0/P1 lint 问题
  3. 自动 commit（提交信息含 lite task ID）
     例: "fix(auth): L-003 修复空密码验证 [3/3 S]"
  4. 更新 state.yaml
```

**与 Full Mode Review 的区别：**
- 不做人工 Code Review（除非用户要求）
- 不做需求合规全量检查（lite task 本身就是 spec）
- 不做 SOLID 分析

### Lite Task YAML 格式

```yaml
# .step/lite/L-{seq}.yaml
id: L-001
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
  - id: S-L001-01
    given: "password 为空字符串"
    when: "POST /api/register"
    then: "返回 400 + { error: 'password required' }"
    test_file: "test/auth/register.test.ts"
    test_name: "[S-L001-01] 空密码返回 400"
    test_type: unit
    status: not_run

  - id: S-L001-02
    given: "password 为 null"
    when: "POST /api/register"
    then: "返回 400"
    test_file: "test/auth/register.test.ts"
    test_name: "[S-L001-02] null 密码返回 400"
    test_type: unit
    status: not_run

done_when:
  - "gate.sh lite L-001"
```

### 任务归档

完成的 Lite 任务可以归档到 `.step/archive/`，保持 `.step/lite/` 目录清洁：

```
完成 L-001 → 移动到 .step/archive/2026-02-15-L-001.yaml
完成 T-003 → 移动到 .step/archive/2026-02-15-T-003.yaml
```

归档规则：
- 任务 status 为 done 且 gate 通过
- 文件名加日期前缀便于按时间查找
- 归档不是删除，仍可 grep 搜索历史决策

### Lite vs Full 对比

| 维度 | Full Mode | Lite Mode |
|------|-----------|-----------|
| 阶段数 | 6 (Phase 0-5) | 3 (L1-L3) |
| 确认轮数 | 多次分段确认 | 一次确认 |
| Baseline | 创建 + 冻结 | 复用已有 |
| ADR | 必须记录 | 按需 |
| TDD | ✅ 必须 | ✅ 必须 |
| BDD 覆盖 | ✅ 100% | ✅ 100% |
| Gate | standard (含 build) | lite (跳过 build) |
| e2e 测试 | ✅ 必须 | 按需 |
| Code Review | 人工审查 | 自动化 |
| 预计时间 | 65-110 min | 10-15 min |

### 模式升级

如果 L2 执行中发现：
- 影响文件 > 3 个
- 需要新的架构决策
- 发现关联 bug 需要修复

→ **必须升级到 Full Mode**：
1. 将 lite task 转换为 Full task（创建 T-xxx.yaml）
2. 补充 baseline 更新（如需要）
3. 从 Phase 3 开始补完场景矩阵
4. 后续按 Full Mode 执行

---

## 9 个反馈逐一对应

| # | 反馈 | 本文档如何处理 |
|---|------|---------------|
| 1 | Phase 0/2 应该是开放式讨论 | Phase 0/2 改为"用户主导的开放式讨论"，Phase 1/3 才用选择题确认细节 |
| 2 | Post-MVP 变更和 bug 修复 | 新增"Post-MVP"章节：Change Request（需求变更）+ Hotfix（bug）+ 约束变更 |
| 3 | 场景规则是 BDD | 场景 = BDD Given/When/Then = 行为规格。测试类型由 test_type 字段指定 |
| 4 | 用 hook 保证规则生效 | 新增 SessionStart hook（自动注入 state.yaml 到上下文）+ `/step` 命令 |
| 5 | 统一使用 opencode，删除 tool | config.yaml 中删除 tool 字段，只保留 model 路由 |
| 6 | review 模型可选，规则参考 code-review-expert | Review 模型用户指定；审查规则以需求合规（baseline/PRD/BDD/Plan/ADR）为第一优先级，code-review-expert 项为第二优先级 |
| 7 | gate 失败如何处理 | 新增"Gate 失败处理流程"：Opus/Codex xhigh 先分析根因 → 分类修复最多 3 轮 → 仍失败标 blocked |
| 8 | 初始化做成 /step 命令 | 创建 `commands/step/step.md`，检测 .step/ 是否存在：不存在则初始化，存在则恢复 |
| 9 | 测试代码模型可配置 | config.yaml 中 test_writing.model 可配置（默认 codex），建议与实现模型不同 |
