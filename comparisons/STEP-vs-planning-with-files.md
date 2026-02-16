# STEP vs planning-with-files（基于当前实现）

## 一句话结论

STEP 是“协议 + 状态机 + 可执行 gate + 角色路由”的工程执行系统；planning-with-files 是“文件化计划/记录方法”。

## 核心定位差异

- STEP：覆盖从 Discovery 到 Review 的完整研发闭环，强调可验证交付。
- planning-with-files：强调把计划、发现、进度写入文件，提升上下文连续性。

## 当前实现层面的关键对比

### 1) 生命周期覆盖

- STEP 已实现阶段化流程（Phase 0-5），并有 Lite Mode 作为短路径。
- planning-with-files 本质上不规定完整研发阶段，只规定“怎么记计划/发现/进度”。

### 2) 可执行约束

- STEP 有真实脚本门禁：`scripts/gate.sh`、`scripts/scenario-check.sh`、`scripts/step-stop-check.sh`。
- planning-with-files 主要依赖执行纪律，不内置项目级 gate 脚本约束。

### 3) 结构化状态与恢复

- STEP 用 `.step/state.yaml` 维护当前 phase/change/task，并通过 `hooks/session-start.sh` 注入上下文。
- STEP 额外维护 `baseline.md`、`decisions.md`、`changes/{change}/findings.md|spec.md|design.md|tasks/`。
- planning-with-files 通常依赖 `task_plan.md/findings.md/progress.md` 组合，状态语义更轻。

### 4) 质量与审查策略

- STEP 强制两阶段 Review（Spec Compliance -> Code Quality），并要求展示新鲜 gate/scenario 证据。
- planning-with-files 可以做 review，但没有内建“两阶段阻断”机制。

### 5) 并行与分支隔离

- STEP 当前通过可选 worktree 模式支持并行线：`worktree.enabled=true` 时自动走 `scripts/step-worktree.sh`。
- worktree 合并策略在 STEP 内置（冲突自动策略 + 冲突报告 + 合并后归档 + 清理）。
- planning-with-files 本身不提供 git/worktree 自动化流程。

## 适用场景建议

- 选 STEP：你需要“从需求到交付”的可审计流程，且希望有脚本级质量闸门。
- 选 planning-with-files：你只想提升计划透明度，不想引入完整协议和角色分工。
- 混合用法：用 STEP 执行主流程，同时把额外调研细节继续沉淀到 findings 文档。

## 风险与成本

- STEP 成本：流程更重，需要维护 `.step/` 状态与脚本。
- planning-with-files 风险：执行一致性依赖人和提示词，缺少硬门禁时更易漂移。

## 优劣对比

| 维度 | STEP | planning-with-files |
|---|---|---|
| 上手成本 | 较高：需要初始化协议、脚本和状态文件 | 低：以文档为核心，快速落地 |
| 执行约束 | 强：有 gate/scenario-check 和证据要求 | 中：主要依赖执行纪律 |
| 会话连续性 | 强：state + hook 自动恢复 | 中：依赖手工维护进度文档 |
| 质量下限 | 高：两阶段 Review + 脚本门禁 | 中低：缺少内建硬门禁 |
| 维护成本 | 较高：需维护 `.step/` 结构与脚本 | 低：维护少量文档即可 |

## 最终判断

如果你的目标是“交付质量可验证 + 过程可回溯”，当前实现下 STEP 明显更强；
如果目标只是“写清楚要做什么”，planning-with-files 更轻、更快。
