# STEP vs OpenSpec（基于当前实现）

## 一句话结论

STEP 偏“执行协议与质量控制”，OpenSpec 偏“规格变更管理与提案审阅”。

## 当前 STEP 的实际能力边界

- 统一变更结构：`.step/changes/{change}/findings.md|spec.md|design.md|tasks/`
- 全局状态机：`.step/state.json`（phase/change/task 追踪）
- 可执行质量脚本（安装目录）：`${OPENCODE_PLUGIN_ROOT:-$HOME/.config/opencode/tools/step}/scripts/gate.sh`、`${OPENCODE_PLUGIN_ROOT:-$HOME/.config/opencode/tools/step}/scripts/scenario-check.sh`、`${OPENCODE_PLUGIN_ROOT:-$HOME/.config/opencode/tools/step}/scripts/step-archive.sh`
- 两阶段 review：先需求合规，再代码质量
- 可选 worktree 流程：`${OPENCODE_PLUGIN_ROOT:-$HOME/.config/opencode/tools/step}/scripts/step-worktree.sh`（创建、合并、冲突报告、归档、清理）

## 与 OpenSpec 的主要差异

### 1) 关注中心

- STEP：把“做事过程”标准化（阶段、执行、验证、归档）。
- OpenSpec：把“规格变更”标准化（提案、审批、变更追踪）。

### 2) 代码执行耦合度

- STEP 与代码执行深度耦合，内置测试/构建/gate 路径。
- OpenSpec 对实现层通常更中立，适合作为规范治理层。

### 3) 证据形态

- STEP 证据是运行产物：`evidence/*.json|*.md` + gate 输出。
- OpenSpec 证据多为文档审阅历史与变更说明。

### 4) 对 AI 代理的约束方式

- STEP 用 skill + hooks + 脚本组合，强调“说通过前必须给证据”。
- OpenSpec 通常不直接绑定 agent 执行策略。

### 5) 并行开发支撑

- STEP 通过 worktree 自动流程支持并行变更落地，并能在 finalize 阶段处理合并冲突。
- OpenSpec 侧重规格并行，不直接处理代码 worktree 合并细节。

## 选型建议

- 选 STEP：团队的主要痛点在“实现质量、执行一致性、回归验证”。
- 选 OpenSpec：团队主要痛点在“跨团队提案评审、规范审计、设计治理”。
- 组合：OpenSpec 管“要改什么与为什么”，STEP 管“怎么落地并验证”。

## 优劣对比

| 维度 | STEP | OpenSpec |
|---|---|---|
| 覆盖重心 | 实施与验证：从任务到交付闭环 | 规格治理：提案、评审、变更管理 |
| 与代码耦合 | 高：直接绑定测试/构建/gate | 低：偏规范层，不强绑实现路径 |
| 证据形态 | 运行证据（evidence + gate 输出） | 文档证据（提案/审阅记录） |
| AI 执行约束 | 强：skill + hooks + 脚本门禁 | 中：更多依赖流程治理本身 |
| 跨团队治理 | 中：可做但不是核心优势 | 强：天然适配跨团队规范协作 |

## 当前实现下的结论

在“从需求到可发布代码”的链路上，STEP 的落地能力更强；
在“组织级规格治理与提案流程”上，OpenSpec 更轻且更易跨团队推广。
