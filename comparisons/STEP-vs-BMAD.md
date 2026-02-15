# STEP vs BMAD-METHOD 详细对比

本文对比 STEP Protocol 与 BMAD-METHOD 的定位、生命周期、角色系统、执行保证机制与生态差异，给出适用场景建议。

## 1. 定位与哲学差异

STEP：强调“可执行、可验证、可恢复”的工程化协议。核心思路是把需求、设计、计划、执行与验收固化为明确的阶段与工具链，并通过脚本与钩子形成硬性约束，减少执行偏差和需求漂移。

BMAD-METHOD：强调“规模自适应、角色丰富、流程模板化”的方法论生态。核心思路是通过大量专用角色与工作流，覆盖从分析到实现的全过程，允许不同复杂度项目选择不同深度路径。

## 2. 生命周期覆盖对比

| STEP | BMAD-METHOD | 关键差异 |
| --- | --- | --- |
| Phase 0 Discovery | Analysis | STEP 有明确阶段入口与讨论模式；BMAD 由工作流引导进入分析 |
| Phase 1 PRD | Planning（产品简报/PRD） | STEP 把 PRD 作为强制阶段；BMAD 可在不同轨道中裁剪 |
| Phase 2 Tech Design | Solutioning（架构/设计） | STEP 强调技术设计文档与约束；BMAD 以多角色协作推进 |
| Phase 3 Plan & Tasks | Planning（epics/stories/sprint） | STEP 固化计划与任务拆解；BMAD 工作流粒度更细 |
| Phase 4 Execution | Implementation | STEP 绑定执行与质量门禁；BMAD 依赖流程指导与代码审查 |
| Phase 5 Review | Implementation/Review | STEP 强调验收与回顾阶段；BMAD 未强制独立阶段 |

## 3. 角色/Agent 系统对比

STEP：7 个角色（PM、Architect、QA、Developer、Designer、Reviewer、Deployer），通过 opencode 子代理文件（agents/*.md）进行模型绑定。角色较少但职责清晰，强调“关键角色闭环”和强一致性：PRD、架构、体验与界面、测试、实现、部署与审查必须覆盖。角色的权威性来自可执行工具链（脚本与钩子），而不是角色数量。

BMAD-METHOD：12+ 专用角色（Analyst、PM、Architect、Developer、UX Designer、Scrum Master、QA、Code Reviewer、DevOps、Data Modeler、Technical Writer 等），强调角色生态与可扩展性。角色即工作流入口，支持 Party Mode 多角色协作讨论与任务拆解。角色数量多、覆盖面广，利于复杂项目与跨职能协作，但约束更多来自 prompt 规则与流程习惯。

结论：STEP 以“少角色+硬保证”换取一致性和可执行性；BMAD 以“多角色+流程丰富”换取覆盖面与适配性。对于复杂系统、跨部门协同，BMAD 的角色生态优势明显；对于交付可靠性与统一执行规范，STEP 更强。

## 4. 执行保证机制对比（硬 vs 软）

STEP 的硬保证：
- `gate.sh` 统一运行 lint/typecheck/test/build，不通过则阻断完成。
- `scenario-check.sh` 校验 BDD 场景矩阵 100% 覆盖，绑定 `[S-xxx-xx]` scene ID。
- SessionStart Hook 自动注入 `state.yaml`，恢复上下文。
- `baseline.md` 确认与 Change Request 机制防止需求漂移。
- 模板结构与子代理模型绑定为强约束。

BMAD 的软保证：
- 依赖 prompt 级角色行为、工作流模板与人机协作习惯。
- 无强制门禁脚本、无自动会话恢复、无基线确认。

结论：STEP 更接近“工程化执行系统”；BMAD 更接近“流程与角色方法论”。

## 5. 工作流对比

STEP：阶段流驱动，必须按 Phase 0→5 推进。Phase 0/2 可开放讨论，Phase 1/3 采用结构化确认，强调阶段性签收与责任闭环。

BMAD：命令流驱动，使用 slash commands 组合路径。Quick Flow（/quick-spec → /dev-story → /code-review）适合小改动；完整路径覆盖 product brief 到 story 执行。不同复杂度选择不同轨道，灵活但不强制。

## 6. Session 恢复与状态管理

STEP：SessionStart Hook 自动注入 `state.yaml`，配合阶段状态管理，能在会话中断后持续推进，降低上下文丢失风险。

BMAD：无自动 session 恢复机制，状态主要依赖文档与上下文习惯。

## 7. 平台兼容性与生态

STEP：基于 opencode 插件体系，执行链条与模板高度内聚，适配面相对集中。

BMAD：npm 安装，支持 Claude Code、Cursor、Windsurf 等多平台；模块生态丰富（BMM、BMad Builder、TEA、Game Dev Studio、Creative Intelligence Suite），扩展性强。

## 8. STEP 可以借鉴什么

- Scale-Domain-Adaptive：根据项目复杂度自动调整规划深度。
- Party Mode：多角色在同一会话协同讨论，提升跨域决策效率。
- 角色生态更丰富：补足 UX、DevOps、Tech Writer 等非研发角色。
- 更大的模块化生态：支持非软件开发场景与自定义引擎扩展。

## 9. BMAD 缺少什么

- 可执行门禁脚本（lint/typecheck/test/build 集成阻断）。
- BDD 场景矩阵与 scene ID 绑定验证机制。
- 自动 session 恢复与 `state.yaml` 注入。
- baseline 确认与变更请求机制。

## 10. 总结与适用场景建议

STEP 更适合：
- 需要强执行保证、质量门禁与可追踪的工程交付。
- 长周期项目或多人协作，担心需求漂移与执行偏差。
- 需要严格测试覆盖与可验证交付标准。

BMAD-METHOD 更适合：
- 需求多变或复杂度差异明显的项目，需要灵活深度规划。
- 跨职能协作场景，强调角色丰富与流程模板化。
- 需要快速上手、在多工具平台统一流程的团队。

一句话：STEP 是“硬保证的工程协议”，BMAD 是“角色驱动的流程生态”。选择取决于你更看重交付的可验证性，还是流程的适配性与生态广度。
