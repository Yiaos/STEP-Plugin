# STEP vs planning-with-files 详细对比

本文对比 STEP Protocol 与 planning-with-files 的定位、Session 恢复、执行保证与互补性，给出组合使用建议。

## 1. 定位差异

**STEP**：全生命周期开发协议。从需求发现到交付审查的 6 阶段状态机，通过可执行门禁、角色绑定和 Hook 注入实现"可验证完成"。

**planning-with-files**：上下文持久化工具（Manus 风格）。核心理念是"文件系统作为外部 RAM"，解决 AI 在长对话中因上下文窗口限制导致的遗忘和幻觉问题。

一句话：STEP 管"做什么、怎么验收"；planning-with-files 管"别忘了、别幻觉"。

## 2. 解决的核心问题

| 痛点 | STEP 的解法 | planning-with-files 的解法 |
|------|-----------|------------------------|
| **任务完成度不足** | BDD 场景矩阵 + gate.sh 质量门禁 | ❌ 不涉及 |
| **跨 Session 上下文丢失** | SessionStart Hook 自动注入 state.yaml | session-catchup.py 半自动恢复 |
| **长对话遗忘/幻觉** | ⚠️ PreToolUse 注入规则 + Stop hook 检查脚本（中等保证） | 2-Action Rule 强制每 2 次操作写入文件 |
| **需求漂移** | baseline.md 冻结 + CR 机制 | ❌ 不涉及 |
| **同一错误反复重试** | gate 失败 → 强模型分析根因 → 最多 3 轮 | Three-Strikes Protocol → 3 次后停止求助 |
| **决策遗忘** | decisions.md ADR 日志 | Pre-decision Read 重读 task_plan.md |

**互补关系明显**：STEP 解决的问题（完成度、需求漂移）和 planning-with-files 解决的问题（遗忘、幻觉）几乎不重叠。

## 3. 文件管理对比

### STEP 的 `.step/` 目录
```
.step/
├── config.yaml          # 模型路由 & gate 命令配置
├── state.yaml           # 状态机（Phase, Task, next_action）
├── baseline.md          # 需求基线（冻结后不可直接改）
├── decisions.md         # 架构决策日志 (ADR)
├── tasks/               # 任务 YAML + BDD 场景矩阵
├── change-requests/     # 变更请求（YYYY-MM-DD-CR-xxx.yaml）
└── evidence/            # gate 运行证据
```

**特点**：结构化 YAML/MD 文件，每个文件有明确职责。state.yaml 是状态机核心，baseline.md 有冻结契约。

### planning-with-files 的 3 个文件
```
project/
├── task_plan.md      # 路线图、阶段、任务拆解、决策、错误日志
├── findings.md       # 需求分析、调研发现、技术决定、多模态信息
└── progress.md       # 操作日志、测试结果、5 问重启检查表
```

**特点**：轻量 3 文件方案，内容自由格式。task_plan.md 承担了 STEP 中多个文件的职责（计划 + 决策 + 错误日志），灵活但缺乏结构化约束。

### 对比

| 维度 | STEP | planning-with-files |
|------|------|---------------------|
| 文件数量 | 5+ 结构化文件 | 3 个自由格式文件 |
| 状态管理 | state.yaml（机器可读） | task_plan.md 中的文本标记 |
| 需求管理 | baseline.md（可冻结） | ❌ 无 |
| 操作日志 | evidence/ 目录 | progress.md |
| 调研记录 | ❌ 不专门管理 | findings.md（核心优势） |
| 错误追踪 | gate 输出 + evidence | task_plan.md 中的错误日志 |

## 4. Session 恢复机制对比

这是两个工具的核心交叉领域，值得深入对比。

### STEP 的 SessionStart Hook（全自动）

```
新 Session 启动
  → opencode 触发 SessionStart 事件
  → hooks/session-start.sh 检测当前目录是否有 .step/
  → 有 → 读取 state.yaml，输出 JSON additionalContext
  → opencode 自动注入到 LLM 上下文
  → LLM 看到: 📍 Phase X | Task: T-xxx | Status: xxx | Next: xxx
  → 从 next_action 精确恢复
```

**优势**：
- 零人工操作，Hook 触发是确定性的
- next_action 精确到文件名和具体动作
- 恢复的是**状态**（当前阶段 + 任务 + 下一步），不是全部历史

**局限**：
- 只恢复结构化状态，不恢复"思考过程"和"细节上下文"
- 依赖 LLM 遵守 next_action（软保证）

### planning-with-files 的 session-catchup.py（半自动）

```
/clear 后或新 Session
  → 用户手动运行 session-catchup.py
  → 脚本读取 task_plan.md + findings.md + progress.md
  → 输出上下文摘要
  → LLM 通过 pre/post 工具调用钩子被强制看到计划文件
  → 从文件中的任务标记继续
```

**优势**：
- 恢复的信息更丰富（包含调研细节、操作日志、错误历史）
- findings.md 保留了"为什么做这个决定"的推理过程
- Pre/Post 工具调用钩子持续提醒（不只是开头）

**局限**：
- 需要手动触发 session-catchup.py
- 文件可能与实际状态不一致（如果 AI 没严格更新）
- 没有结构化状态机，恢复精度取决于文件质量

### 互补组合方案

最强 Session 恢复 = STEP Hook（结构化状态自动注入）+ planning-with-files（细节上下文持久化）：
- STEP 提供**快速恢复**："你在 Phase 4，当前任务 T-003，下一步写 auth.test.ts"
- planning-with-files 提供**深度恢复**："上次调研发现 JWT 方案有 CSRF 风险，选了 HttpOnly Cookie 方案，原因见 findings.md"

## 5. 执行保证对比

| 保证机制 | STEP | planning-with-files |
|---------|------|---------------------|
| **质量门禁** | ✅ gate.sh（lint + typecheck + test + build），脚本级硬阻断 | ❌ 无 |
| **场景覆盖** | ✅ scenario-check.sh 验证 BDD 场景 ID 100% 覆盖 | ❌ 无 |
| **防遗忘** | ⚠️ PreToolUse 注入行为规则 + 注意力管理段落 + Stop hook 检查脚本 | ✅ 2-Action Rule（每 2 次操作写文件） |
| **防反复犯错** | ✅ gate 失败 → 强模型分析根因 → 最多 3 轮自动修复 | ✅ Three-Strikes Protocol → 3 次失败停止求助 |
| **防决策遗忘** | ✅ decisions.md ADR 日志 | ✅ Pre-decision Read（重大决定前重读 task_plan.md） |
| **模型绑定** | ✅ agents/*.md → subagent 模型绑定 | ❌ 无 |
| **自动注入** | ✅ SessionStart Hook | ⚠️ Pre/Post 工具调用钩子（持续提醒但不注入状态） |

**保证强度**：
- STEP 有 4 个硬保证（gate.sh、scenario-check.sh、subagent 绑定、SessionStart Hook）
- planning-with-files 有 0 个硬保证，全部是 prompt 级 + 钩子提醒

## 6. 生命周期覆盖差异

| 阶段 | STEP | planning-with-files |
|------|------|---------------------|
| 需求发现 | ✅ Phase 0 Discovery | ❌ |
| 需求定义 | ✅ Phase 1 PRD → baseline.md | ❌ |
| 技术设计 | ✅ Phase 2 Tech Design → ADR | ❌ |
| 任务规划 | ✅ Phase 3 Plan → BDD 场景矩阵 | ✅ task_plan.md |
| 执行编码 | ✅ Phase 4 Execution (TDD + gate) | ✅ 持续记录 progress.md |
| 审查验收 | ✅ Phase 5 Review | ❌ |
| 调研记录 | ❌ | ✅ findings.md |
| 操作日志 | ⚠️ evidence/ (gate 输出) | ✅ progress.md (全过程) |
| Post-MVP | ✅ CR / Hotfix / 约束变更 | ❌ |

**结论**：STEP 覆盖 9/11 阶段，planning-with-files 覆盖 3/11 阶段。但 planning-with-files 在"调研记录"和"操作日志"上比 STEP 更深入。

## 7. 互补性分析

两个工具的设计目标几乎正交：

```
STEP 管"结构"：
  ├── 阶段流转（Phase 0→5）
  ├── 质量门禁（gate.sh）
  ├── 需求防漂移（baseline freeze）
  └── 角色制衡（PM/Architect/QA/Developer）

planning-with-files 管"记忆"：
  ├── 调研细节（findings.md）
  ├── 操作历史（progress.md）
  ├── 防遗忘（2-Action Rule）
  └── 防重复犯错（Three-Strikes）
```

**组合使用时**：
- STEP 的 `.step/` 目录管理生命周期状态和门禁
- planning-with-files 的 3 个文件管理执行细节和调研上下文
- SessionStart Hook 恢复"在哪"，findings.md 恢复"为什么"
- gate.sh 保证"做完了"，progress.md 保证"没忘记"

## 8. STEP 可以借鉴什么

| 机制 | 描述 | STEP 可以如何吸收 |
|------|------|----------------|
| **2-Action Rule** | 每 2 次操作写入文件 | 在 Phase 4 Execution 中增加"每完成一个场景，更新 state.yaml"的硬规则 |
| **Three-Strikes Protocol** | 同一错误 3 次后停止 | STEP 已有类似机制（gate 失败最多 3 轮），可以扩展到编码阶段 |
| **Pre-decision Read** | 重大决定前重读计划 | 在 Phase 2/3 角色切换时，强制重读 baseline.md 和 decisions.md |
| **findings.md** | 专门的调研记录文件 | 考虑在 `.step/` 中增加 `research/` 目录 |
| **5 问重启检查表** | Session 恢复时的验证清单 | 可以整合到 SessionStart Hook 的输出中 |

## 9. planning-with-files 缺少什么

1. **全生命周期覆盖** — 不管需求、设计、验收，只管执行阶段的记录
2. **质量门禁** — 没有 gate.sh 或任何可执行的质量检查
3. **角色系统** — 没有 PM/Architect/QA/Developer 的分工和制衡
4. **需求管理** — 没有 baseline 冻结、Change Request 机制
5. **BDD 场景覆盖** — 没有场景矩阵和覆盖率验证
6. **结构化状态** — task_plan.md 是自由文本，不是机器可读的 state.yaml
7. **模型路由** — 没有 agent 定义文件和 subagent 模型绑定

## 10. 总结：独用 vs 组合使用

### 独用场景

| 场景 | 推荐 |
|------|------|
| 全新 MVP 产品开发 | STEP — 需要全生命周期管理 |
| 复杂调研 + 长期重构 | planning-with-files — 调研记录和防遗忘是核心需求 |
| 需求明确的功能交付 | STEP — 门禁和场景覆盖保证质量 |
| 探索性原型开发 | planning-with-files — 灵活记录，不需要门禁 |

### 组合使用（推荐）

```
STEP .step/ + planning-with-files 3文件

.step/                              project/
├── state.yaml    ← 状态恢复        ├── task_plan.md    ← 计划追踪
├── baseline.md   ← 需求基线        ├── findings.md     ← 调研记录
├── decisions.md  ← 架构决策        └── progress.md     ← 操作日志
├── tasks/        ← BDD 场景
└── evidence/     ← gate 证据

Session 恢复: Hook 注入 state.yaml + 重读 findings.md
质量保证: gate.sh + scenario-check.sh
防遗忘: 2-Action Rule + Pre-decision Read
```

**一句话**：STEP 管骨架（生命周期 + 门禁），planning-with-files 管血肉（细节 + 记忆）。独用各有所长，组合使用最强。
