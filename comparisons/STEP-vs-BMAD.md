# STEP vs BMAD-METHOD 详细对比

> 基于 STEP baseline v2（2026-02-16）重新对比。

## 1. 定位差异

**STEP**：全生命周期开发协议。强调"可执行、可验证、可恢复"——通过脚本门禁、角色对抗、Hook 注入和状态机形成多层保证。

**BMAD**：AI 驱动的敏捷开发框架。强调"规模自适应、角色丰富、流程模板化"——通过大量专用角色与工作流覆盖从分析到实现的全过程。

一句话：STEP 是"硬保证的工程协议"，BMAD 是"角色驱动的流程生态"。

## 2. 生命周期覆盖

| 阶段 | STEP | BMAD | 差异 |
|------|------|------|------|
| 需求发现 | Phase 0 Discovery | Analysis + product-brief | STEP 有明确阶段入口；BMAD 由工作流引导 |
| 需求定义 | Phase 1 → baseline 确认 | create-prd | STEP 有用户确认契约；BMAD 的 PRD 是参考文档 |
| 技术设计 | Phase 2 → ADR | create-architecture | STEP 记录 ADR；BMAD 多角色协作推进 |
| 任务规划 | Phase 3 → BDD 场景矩阵 | epics/stories/sprint | STEP 绑定场景 ID；BMAD 粒度更细 |
| 执行编码 | Phase 4（TDD + gate 检查点） | dev-story | STEP 有脚本级门禁；BMAD 依赖流程引导 |
| 代码审查 | Phase 5 Review（Reviewer agent） | code-review workflow | STEP 有"需求合规 > 代码质量"的固定步骤 |
| Session 恢复 | SessionStart Hook 全自动 | ❌ 需人工重新加载 | STEP 独有优势 |
| Post-MVP | 新增功能变更 / Hotfix / 约束变更 / Baseline 整理 | sprint 迭代 | STEP 有审计链；BMAD 更灵活 |
| 注意力管理 | 三层 Hook + 2-Action Rule | ❌ | STEP 独有 |

## 3. 角色系统对比

### STEP：7 角色 + 硬绑定

| 角色 | 绑定方式 | 对抗性 |
|------|---------|--------|
| PM | agents/pm.md → subagent 模型绑定 | 定义"做什么" |
| Architect | agents/architect.md → subagent | 定义"怎么做" |
| QA | agents/qa.md → subagent | 定义"怎么破坏它" |
| Developer | agents/developer.md → subagent | 只做被定义的事 |
| Designer | agents/designer.md → subagent | 负责体验与界面 |
| Reviewer | agents/reviewer.md → subagent | 独立审查交付物 |
| Deployer | agents/deployer.md → subagent | 部署策略（可选） |

特点：每个角色有 opencode agent 定义文件 + 模型路由。QA 与 Developer 天然对抗（写测试 ≠ 写实现）。Reviewer 有"严禁空洞 APPROVE"的硬约束。

### BMAD：12+ 角色 + prompt persona

Analyst、PM、Architect、Developer、UX Designer、Scrum Master、QA (Quinn)、Code Reviewer、DevOps、Data Modeler、Technical Writer、BMad Help 等。

特点：角色更多，覆盖面广（UX、DevOps、Tech Writer 等 STEP 不涉及的领域）。Party Mode 允许多角色同时讨论。Scale-Adaptive 自动调整规划深度。但所有角色都是 prompt 级 persona，无模型绑定。

### 对比

| 维度 | STEP | BMAD |
|------|------|------|
| 角色绑定 | subagent 文件 + 模型路由 | prompt persona |
| 对抗性 | QA ≠ Developer，Reviewer 独立审查 | 角色间无结构化对抗 |
| 覆盖面 | 7 角色，聚焦核心工程链 | 12+ 角色，覆盖 UX/DevOps/Tech Writer |
| 多角色协作 | 顺序对抗（阶段切换） | Party Mode 同时讨论 |
| 规模适应 | Full/Lite 两档（手动） | Scale-Adaptive 自动 |

## 4. 执行保证对比

| 机制 | STEP | BMAD |
|------|------|------|
| 可执行门禁 | ✅ gate.sh + scenario-check.sh + step-stop-check.sh | ❌ |
| BDD 场景 ID 硬匹配 | ✅ [S-xxx-xx] 覆盖率验证 | ❌ |
| Agent 模型绑定 | ✅ 不同角色→不同模型 | ❌ 同模型不同 persona |
| Hook 自动注入 | ✅ 四层（SessionStart/PreToolUse/PostToolUse/Stop） | ❌ |
| 需求基线确认 | ✅ baseline + 变更审计链 | ❌ PRD 无确认机制 |
| Gate 失败处理 | ✅ 根因分析 → 3 轮 → blocked | ❌ |
| 注意力管理 | ✅ 2-Action Rule + Pre-decision Read | ❌ |
| 倒序状态 | ✅ 最新决策/进度在 state.yaml 头部 | ❌ |

STEP 的保证是"可执行门禁 + prompt 约束"双层；BMAD 全部是 prompt 级。

## 5. 平台与生态

| 维度 | STEP | BMAD |
|------|------|------|
| 平台支持 | opencode 唯一 | Claude Code, Cursor, Windsurf 等多平台 |
| 安装方式 | bash install.sh | npx bmad-method install |
| 社区 | 新项目 | 35k+ stars, 111+ contributors, Discord |
| 模块生态 | 单一插件 | BMM, Builder, TEA, Game Dev Studio 等 |

这是 BMAD 的最大优势——生态广度和社区规模。

## 6. 可借鉴点

| BMAD 特性 | 评估 |
|-----------|------|
| Scale-Adaptive 自动调整深度 | 有参考价值。STEP 的 Lite/Full 手动切换已够用。Phase 0 由 PM 判断复杂度，自动判断准确性存疑 |
| Party Mode 多角色同时讨论 | 有趣但 opencode 不支持并行 agent 对话。STEP 的顺序对抗（阶段切换）已实现类似效果 |
| 更多角色（UX、DevOps、Tech Writer） | 不需要。STEP 的 Designer 已覆盖 UX，Deployer 覆盖部署策略。角色多不等于更好 |
| 模块生态扩展 | 长期方向可参考，但当前阶段聚焦核心协议更重要 |

## 7. BMAD 缺少什么

1. 可执行门禁脚本
2. BDD 场景矩阵 + ID 硬匹配
3. 自动 Session 恢复
4. 需求基线确认 + 变更审计链
5. 三层注意力管理 Hook
6. 角色对抗性机制（QA ≠ Developer）
7. Gate 失败分级处理
8. 倒序状态机（最新信息优先注入）

## 8. 总结

STEP 和 BMAD 是两种不同的设计哲学：STEP 用"少角色 + 硬门禁 + 状态机"换取执行可靠性，BMAD 用"多角色 + 流程丰富 + 多平台"换取覆盖面和适配性。STEP 在执行保证层级上显著强于 BMAD（脚本级 vs prompt 级），BMAD 在平台兼容性和社区生态上显著强于 STEP。两者不适合组合使用——定位重叠且哲学冲突。
