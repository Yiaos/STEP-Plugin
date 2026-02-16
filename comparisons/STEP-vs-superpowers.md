# STEP vs superpowers 详细对比

> 基于 STEP baseline v2（2026-02-16）重新对比。

## 1. 定位差异

**STEP**：全生命周期开发协议。6 阶段状态机 + 脚本级硬门禁 + 7 角色对抗 + 三层注意力 Hook + 全自动 Session 恢复。目标是可验证交付。

**superpowers**：工程纪律技能套件。用铁律式 prompt 语言约束 AI 行为，防止捷径与猜测。目标是技术严谨。

一句话：STEP 是"全链路结构化协议 + 可执行保证"，superpowers 是"执行节点铁律纪律"。

## 2. 覆盖范围

| 阶段 | STEP | superpowers |
|------|------|-------------|
| 需求发现 | ✅ Phase 0 Discovery | ✅ brainstorming |
| 需求定义 | ✅ Phase 1 → baseline 确认 | ❌ |
| 技术设计 | ✅ Phase 2 → ADR | ❌ |
| 任务规划 | ✅ Phase 3 → BDD 场景矩阵 | ✅ writing-plans |
| 执行编码 | ✅ Phase 4（TDD + gate 检查点） | ✅ executing-plans |
| 测试 | ✅ QA 角色 + scenario-check.sh | ✅ TDD 铁律 |
| 代码审查 | ✅ Phase 5 Reviewer agent | ✅ code-review 铁律 |
| 调试 | ✅ Gate 失败分级处理 | ✅ systematic-debugging |
| Session 恢复 | ✅ SessionStart Hook 全自动 | ❌ |
| Post-MVP | ✅ 新增功能变更 / Hotfix / Baseline 整理 | ❌ |
| 注意力管理 | ✅ 三层 Hook + 2-Action Rule | ⚠️ 1% 触发规则 |

STEP 覆盖全链路；superpowers 聚焦执行节点纪律。

## 3. 质量保证方式对比（脚本级 vs prompt 级）

| 机制 | STEP | superpowers |
|------|------|-------------|
| 门禁执行 | gate.sh 脚本（确定性结果） | prompt 铁律（概率性遵守） |
| 场景覆盖 | scenario-check.sh 硬匹配 | 无 |
| TDD 保证 | QA 写测试 ≠ Developer 写实现（角色分离） | "无失败测试不得写生产代码"（铁律语言） |
| 审查保证 | Reviewer agent "必须列出至少 3 个具体发现" | "反迎合式回应"（铁律语言） |
| 调试保证 | Gate 失败 → 根因分析 → 3 轮 → blocked（状态机） | "禁止未定位根因就修复"（铁律语言） |
| 证据留存 | evidence/ 目录保存 gate/review 结果 | "必须展示最新输出"（铁律语言） |
| 防撒谎 | Developer agent "严禁在测试通过上撒谎" + gate.sh 真实执行 | 铁律语言约束 |

核心差异：STEP 的保证分两层——Agent 级 prompt 约束 + 脚本级硬验证。superpowers 只有 prompt 层。但 superpowers 的铁律语言更极端直接（"全部删除并重来"），对 LLM 的心理压迫更强。

## 4. 工程严谨性逐项对比

| 纪律点 | STEP 机制 | superpowers 机制 |
|--------|----------|-----------------|
| 不跳过测试 | scenario-check.sh 硬匹配 + QA/Developer 角色分离 | TDD 铁律 + "删除并重来" |
| 不猜测错误原因 | Gate 失败 → 强模型根因分析 + QA "严禁猜测" | systematic-debugging 铁律 |
| 不空洞审查 | Reviewer "必须列出至少 3 个具体发现" | receiving-code-review 反迎合 |
| 不跳步执行 | depends_on 依赖链 + gate 阻断 | executing-plans 检查点 |
| 不篡改需求 | baseline + 变更审计链 | 无对应机制 |
| 证据留存 | evidence/ 目录 + gate 结果 | verification-before-completion |
| 不撒谎 | Agent 约束 + gate.sh 真实执行验证 | 铁律语言 |

两者都解决了"如何不作弊"。差异在保证层级：STEP 用脚本提供确定性保证，superpowers 用语言提供概率性保证。

## 5. TDD 对比

STEP：
- config.yaml routing.test_writing 指定 @step-qa 写测试
- Developer 角色写实现（不同 agent、可能不同模型）
- 每场景跑 gate quick（检查点），全部通过跑 gate standard
- scenario-check.sh 验证 BDD 场景 ID 100% 覆盖

superpowers：
- "无失败测试不得写生产代码"铁律
- 写了未覆盖代码则"全部删除并重来"
- 无角色分离，无脚本验证

两者 TDD 纪律一致（先写测试、测试失败、再写实现）。STEP 通过角色分离 + 脚本硬匹配实现；superpowers 通过铁律语言实现。

## 6. 调试方式对比

STEP：
- Gate 失败 → 强模型分析根因（产出 root_cause + category + fix_strategy + affected_files + risk）
- 禁止盲修，多策略则展示给用户选择
- 最多 3 轮自动修复，仍失败则 blocked
- Developer agent "gate 失败：不盲修，报告给 QA 分析"

superpowers：
- systematic-debugging 铁律
- 禁止未定位根因就修复
- 连续 3 次失败必须质疑架构假设

核心纪律一致（先定位根因再修复）。STEP 更结构化（分类 → 分级 → 3 轮 → blocked），superpowers 更简洁直接。

## 7. 计划与执行对比

STEP：
- Phase 3 BDD 场景矩阵驱动任务拆分（每场景 = 一个检查点）
- Phase 4 每场景跑 gate quick，全部通过跑 gate standard
- depends_on 依赖链，Developer "严禁跳过或乱序"
- Gate 失败 3 轮 → blocked 阻断

superpowers：
- writing-plans 2-5 分钟粒度任务拆解
- executing-plans 检查点 + 阻塞处理
- 不得猜测，按序执行

两者都有微粒度执行控制和检查点。STEP 的检查点是脚本级的（gate 真实执行），superpowers 是 prompt 级的。STEP 按 BDD 场景粒度拆分，superpowers 按时间粒度拆分。

## 8. 互补性分析

STEP 已内建了反作弊机制（Agent 约束 + 脚本验证），superpowers 已涵盖了执行控制（检查点 + 阻塞处理）。不是"结构 vs 纪律"的简单互补。

**STEP 有而 superpowers 没有的**：
- 全生命周期 6 阶段
- 会话恢复状态机 + SessionStart Hook
- 可执行门禁脚本
- 需求基线 + 变更审计链
- 角色分离与模型绑定
- Baseline 整理流程
- 倒序 state.yaml

**superpowers 有而 STEP 可以增强的**：
- 极端铁律语言（"删除并重来" > "严禁"）
- dispatching-parallel-agents 并行分工

**两者都有（机制一致，层级不同）**：
- TDD、根因分析、检查点、证据留存、防撒谎

## 9. 可借鉴点

| 特性 | 评估 |
|------|------|
| 铁律极端语言 | 可在 Agent 提示词微调时参考（"严禁"→"违反则删除当前输出并重来"）。措辞微调，不影响架构 |
| dispatching-parallel-agents | 有价值但受限于 opencode 能力（不支持并行 subagent）。记录为未来机会 |

以下 STEP 已具备，无需借鉴：
- ~~微粒度执行控制~~：每场景跑 gate quick 已实现
- ~~执行检查点与阻塞处理~~：gate 失败 → 3 轮 → blocked 已实现
- ~~证据优先原则~~：evidence/ 目录 + gate 结果已实现
- ~~TDD 强制~~：角色分离 + scenario-check.sh 已实现
- ~~调试根因分析~~：Gate 失败分级处理已实现

## 10. superpowers 缺少什么

1. 全生命周期流程
2. 会话恢复与状态机
3. 可执行门禁脚本
4. 需求基线 + 变更审计链
5. 角色分离与对抗性验证
6. BDD 场景矩阵 + ID 硬匹配
7. 结构化证据存档
8. 注意力管理三层 Hook
9. Baseline 整理流程

## 11. 总结

STEP 和 superpowers 的核心差异在于保证层级：STEP 用脚本提供确定性保证 + prompt 提供概率性保证（双层），superpowers 只有 prompt 层概率性保证。STEP 在工程严谨性的每个纪律点上都已具备对应机制，且保证强度更高。superpowers 的独特价值是铁律语言的极端性和并行 agent 分发模式——前者是措辞微调，后者受限于平台能力。
