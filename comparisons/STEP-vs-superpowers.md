# STEP vs superpowers 详细对比

本文对比 STEP Protocol 与 superpowers 技能套件的定位、覆盖范围、质量保证与执行机制差异，并给出互补性分析与组合建议。

## 1. 定位差异（全生命周期协议 vs 工程纪律技能套件）

STEP：全生命周期协议，目标是把需求、设计、计划、执行与验收固化成阶段化流程与可执行门禁，强调可验证交付。

superpowers：工程纪律技能套件，目标是用“强制行为规则”约束 AI 工作方式，防止捷径与猜测，强调技术严谨。

## 2. 覆盖范围对比

STEP：覆盖需求发现到交付复盘的完整链路（Discovery → PRD → Tech Design → Plan → Execution → Review）。

superpowers：覆盖每个编码节点的纪律与行为规范，缺少需求、架构与验收阶段的系统化流程。

结论：STEP 是“全链路结构化协议”，superpowers 是“执行节点纪律约束”。

## 3. 质量保证方式对比（可执行门禁 vs Prompt 铁律）

STEP：通过可执行脚本形成硬门禁。
- `gate.sh` 统一执行 lint/typecheck/test/build，不通过则阻断完成。
- `scenario-check.sh` 校验 BDD 场景矩阵 100% 覆盖，要求场景 ID 绑定。
- SessionStart Hook 自动注入 `state.yaml`，确保会话恢复与阶段一致性。
- `baseline.md` 冻结 + Change Request 防止需求漂移。

superpowers：通过 prompt 级铁律形成软约束。
- “1% 触发规则”要求只要可能就必须调用技能，禁止合理化。
- 多条“铁律”用强制性语言约束行为（如 TDD、debugging）。
- 保障来自文字纪律与流程规范，不具备脚本级阻断。

结论：STEP 的保证是“可执行门禁”，superpowers 的保证是“行为纪律”。

## 4. TDD 对比

STEP：支持在协议层绑定测试书写与场景覆盖（routing.test_writing 指定 @step-qa 写测试、场景 ID 绑定与 BDD 矩阵、QA 与 Developer 天然对抗性）。

superpowers：强制 TDD 铁律，“无失败测试不得写生产代码”；若写了未覆盖代码，要求“全部删除并重来”。

结论：STEP 提供结构化测试绑定；superpowers 提供极强行为约束。

## 5. 代码审查对比

STEP：Phase 5 Review 强调需求合规与交付验收，先确认是否满足 PRD/设计基线，再讨论实现细节。

superpowers：requesting/receiving-code-review 强制“同行评审式反馈”，鼓励技术性异议，明确反对迎合式回应。

结论：STEP 偏“需求合规优先”，superpowers 偏“工程同行评审”。

## 6. 调试方式对比

STEP：门禁失败后要求强模型分析根因，分类定位与修复，再回到 gate 验证。

superpowers：systematic-debugging 铁律，禁止未定位根因就尝试修复；连续失败 3 次必须质疑架构假设。

结论：STEP 强调“门禁驱动 + 根因分析”，superpowers 强调“严密调试纪律”。

## 7. 计划与执行对比

STEP：Phase 3 计划阶段强调 BDD 场景矩阵与任务清单，推动可测试的任务拆解。

superpowers：writing-plans 要求 2-5 分钟粒度任务拆解；executing-plans 强制执行检查点与阻塞处理，不得猜测。

结论：STEP 强调“场景驱动计划”，superpowers 强调“微粒度执行控制”。

## 8. 互补性分析（最佳组合）

STEP 提供全生命周期结构与交付门禁；superpowers 提供每个编码节点的纪律性与反捷径机制。组合使用时：
- STEP 解决“做什么、何时验收、如何保证交付”。
- superpowers 解决“如何不作弊、如何保持工程严谨”。

这是最强组合：结构化流程 + 纪律化执行。

## 9. STEP 可以借鉴什么

- 更强的铁律式语言与反合理化表（减少执行偏差）。
- 2-5 分钟任务粒度拆解，提升执行可控性。
- verification-before-completion 的“证据优先”原则，要求提供最新执行输出。
- dispatching-parallel-agents 的并行分工模式（适用于多模块任务）。

## 10. superpowers 缺少什么

- 全生命周期流程（需求、PRD、架构、验收）
- 会话恢复与状态机（`state.yaml`）
- 可执行门禁与场景覆盖脚本（`gate.sh`、`scenario-check.sh`）
- 基线冻结与变更请求机制（`baseline.md` + CR）

## 11. 总结：为什么应该组合使用

STEP 解决“全链路交付与质量门禁”，superpowers 解决“节点级工程纪律与反捷径”。单独使用时各有强项，组合使用能同时获得结构化交付和严谨执行，是最稳健的工程化协作方案。
