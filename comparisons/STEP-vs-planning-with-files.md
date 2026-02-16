# STEP vs planning-with-files 详细对比

> 基于 STEP baseline v2（2026-02-16）重新对比。

## 1. 定位差异

**STEP**：全生命周期开发协议。6 阶段状态机 + 可执行门禁 + 7 角色对抗 + 三层注意力 Hook + 全自动 Session 恢复。

**planning-with-files**：上下文持久化工具（Manus 风格）。核心理念是"文件系统作为外部 RAM"，通过 3 个文件解决 AI 在长对话中的遗忘和幻觉。

一句话：STEP 管"做什么、怎么验收、怎么恢复"；planning-with-files 管"别忘了、别幻觉"。

## 2. 解决的核心问题

| 痛点 | STEP | planning-with-files |
|------|------|---------------------|
| 任务完成度不足 | BDD 场景矩阵 + gate.sh 硬门禁 | ❌ |
| 跨 Session 上下文丢失 | SessionStart Hook 全自动注入 | session-catchup.py 半自动 |
| 长对话遗忘/幻觉 | 三层 Hook（PreToolUse/PostToolUse/Stop）+ 2-Action Rule（已吸收） | 2-Action Rule（原创）+ 三振出局 |
| 需求漂移 | baseline 确认 + 变更审计链 | ❌ |
| 同一错误反复重试 | gate 失败 → 根因分析 → 3 轮上限 → blocked | Three-Strikes Protocol |
| 决策遗忘 | decisions.md ADR + Pre-decision Read | Pre-decision Read（原创） |
| 调研上下文丢失 | decisions.md "替代方案"字段 | findings.md（更丰富） |

## 3. 文件管理对比

| 维度 | STEP .step/ | planning-with-files 3 文件 |
|------|------------|--------------------------|
| 文件数量 | 5+ 结构化文件 | 3 个自由格式文件 |
| 状态管理 | state.yaml（机器可读状态机） | task_plan.md 中的文本标记 |
| 需求管理 | baseline.md（可确认 + 变更） | ❌ |
| 操作日志 | evidence/ + progress_log | progress.md（全过程流水账） |
| 调研记录 | decisions.md "替代方案"字段 | findings.md（核心优势） |
| 错误追踪 | gate 输出 + evidence/ | task_plan.md 错误日志 |
| 模板强制 | step-init.sh 确定性创建 | 手动创建 |

## 4. Session 恢复对比

### STEP SessionStart Hook（全自动）
- Hook 检测 .step/ → 读取 state.yaml + task + baseline + config → 自动注入 LLM 上下文
- 恢复内容：Phase + Task + Status + next_action + key_decisions + established_patterns
- 倒序 state.yaml：最新决策/进度在头部，head -25 注入时首先看到最新状态
- 零人工操作

### planning-with-files session-catchup.py（半自动）
- 需手动运行脚本 → 读取 3 个文件 → 输出上下文摘要
- 恢复内容：计划 + 调研发现 + 操作历史（更丰富）
- pre/post 钩子持续提醒（不只是开头）

### 对比
| 维度 | STEP | planning-with-files |
|------|------|---------------------|
| 触发方式 | 全自动（Hook） | 手动运行脚本 |
| 恢复精度 | 结构化状态（Phase/Task/next_action） | 自由文本（依赖文件质量） |
| 恢复深度 | 状态 + 模式 + 决策 | 计划 + 调研 + 操作历史 |
| 持续提醒 | PreToolUse/PostToolUse/Stop 三层 | pre/post 工具调用钩子 |

互补性：STEP Hook 恢复"在哪、做什么"，planning-with-files 恢复"为什么、怎么想的"。

## 5. 执行保证对比

| 机制 | STEP | planning-with-files |
|------|------|---------------------|
| 质量门禁 | ✅ gate.sh 脚本级硬阻断 | ❌ |
| 场景覆盖验证 | ✅ scenario-check.sh 硬匹配 | ❌ |
| 防遗忘 | ✅ 三层 Hook + 2-Action Rule | ✅ 2-Action Rule（原创） |
| 防重复犯错 | ✅ gate 失败 → 根因分析 → 3 轮 → blocked | ✅ Three-Strikes |
| 防决策遗忘 | ✅ decisions.md ADR + Pre-decision Read | ✅ Pre-decision Read（原创） |
| 模型绑定 | ✅ 7 角色 subagent | ❌ |
| 自动注入 | ✅ SessionStart + PreToolUse + PostToolUse + Stop | ⚠️ pre/post 钩子 |

STEP 有 4 个硬保证；planning-with-files 有 0 个硬保证，全部 prompt 级 + 钩子提醒。

STEP 已吸收 planning-with-files 的核心注意力管理机制（2-Action Rule、Pre-decision Read），并在此基础上增加了三层 Hook 和脚本级门禁。

## 6. 生命周期覆盖

| 阶段 | STEP | planning-with-files |
|------|------|---------------------|
| 需求发现 | ✅ Phase 0 | ❌ |
| 需求定义 | ✅ Phase 1 → baseline 确认 | ❌ |
| 技术设计 | ✅ Phase 2 → ADR | ❌ |
| 任务规划 | ✅ Phase 3 → BDD 场景矩阵 | ✅ task_plan.md |
| 执行编码 | ✅ Phase 4（TDD + gate 检查点） | ✅ progress.md 记录 |
| 审查验收 | ✅ Phase 5 Review | ❌ |
| 调研记录 | ⚠️ decisions.md 部分覆盖 | ✅ findings.md |
| Post-MVP | ✅ 新增功能变更 / Hotfix / 约束变更 / Baseline 整理 | ❌ |

STEP 覆盖 8/8 核心阶段；planning-with-files 覆盖 2/8，但在调研记录上更深入。

## 7. 互补性分析

STEP 已吸收了 planning-with-files 的两个核心机制：
- **2-Action Rule**：已写入 SKILL.md 注意力规则
- **Pre-decision Read**：已写入 SKILL.md 注意力规则

planning-with-files 仍然独有的价值：
- **findings.md 调研过程记录**：STEP 记录决策结果（ADR），不专门记录调研过程中的中间发现物
- **progress.md 全过程操作日志**：STEP 的 progress_log 是每日摘要，不是逐步流水账

STEP 独有的价值（planning-with-files 不覆盖）：
- 全生命周期 6 阶段 + 7 角色
- 可执行门禁脚本
- 需求基线确认 + 变更审计链
- SessionStart Hook 全自动恢复
- BDD 场景矩阵 + ID 硬匹配

## 8. 可借鉴点

| 特性 | 评估 |
|------|------|
| findings.md 调研记录 | 有价值。decisions.md "替代方案"字段已部分覆盖。等遇到"Session 恢复时缺调研上下文"的实际痛点再加 |
| progress.md 全过程日志 | 不需要。evidence/ + gate 输出已覆盖关键证据，全过程流水账 token 成本高、信噪比低 |
| 5 问重启检查表 | 不需要。SessionStart Hook 自动注入的信息已超过 5 问清单的内容 |

## 9. 总结

planning-with-files 是 STEP 注意力管理机制的重要灵感来源（ADR-001 明确记录了借鉴关系）。STEP 已吸收其核心机制（2-Action Rule、Pre-decision Read）并在此基础上构建了更完整的三层 Hook + 脚本级门禁。planning-with-files 仍然在调研记录（findings.md）上有独特价值，但不构成当前的架构改进需求。
