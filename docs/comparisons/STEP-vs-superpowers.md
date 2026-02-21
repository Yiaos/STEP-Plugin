# STEP vs superpowers（基于当前实现）

## 一句话结论

superpowers 强在“执行纪律提示词体系”，STEP 强在“协议 + 脚本 + 状态 + 归档”的工程闭环。

注：文中脚本指安装目录 `${OPENCODE_PLUGIN_ROOT:-$HOME/.config/opencode/tools/step}/scripts/` 下的 `gate.sh`、`scenario-check.sh`、`step-stop-check.sh` 等。

## 维度对比

### 1) 约束机制类型

- superpowers：核心是强约束提示词与流程指令。
- STEP：提示词约束之外，还有脚本和状态机作为硬执行层。

### 2) 可验证性

- superpowers：强调“先验证再声称完成”，但通常依赖执行者自觉展示证据。
- STEP：把验证固化为脚本路径（gate/scenario-check）和证据目录。

### 3) 会话恢复能力

- superpowers：更像能力包，恢复机制取决于宿主环境。
- STEP：`session-start` hook 自动注入 state/spec/findings/task/baseline/routing。

### 4) 研发流程编排

- superpowers：提供很多高质量工作法（调试、审查、验证），适配范围广。
- STEP：流程更窄但更深，直接面向一个项目的开发生命周期。

### 5) 并行开发

- superpowers：理念上鼓励子代理并行。
- STEP：当前实现通过 `worktree.enabled` + `${OPENCODE_PLUGIN_ROOT:-$HOME/.config/opencode/tools/step}/scripts/step-worktree.sh` 解决并行分支落地。

## STEP 当前实现中吸收到的“纪律化做法”

- 两阶段 review（Spec Compliance -> Code Quality）
- 声称通过前必须展示新鲜运行输出
- Gate 失败先根因分析，再修复，不盲修

## 二者并用建议

- 用 superpowers 作为“行为纪律层”（避免偷步、避免脑补）。
- 用 STEP 作为“项目执行层”（状态管理、脚本 gate、归档和审计）。

## 优劣对比

| 维度 | STEP | superpowers |
|---|---|---|
| 机制类型 | 协议 + 脚本 + 状态机 | 技能/提示词驱动的执行纪律 |
| 可验证性 | 强：运行结果可复现、可落证据 | 中：强调验证，但更多依赖执行习惯 |
| 会话恢复 | 强：session-start 自动注入上下文 | 中：依赖宿主环境能力 |
| 适配范围 | 中：偏软件交付主链路 | 强：适配任务面广、技能丰富 |
| 项目审计性 | 强：changes/archive/evidence 结构化 | 中：缺少统一项目状态与归档模型 |

## 最终判断

若你想要“代理做事更规矩”，superpowers 见效快；
若你要“团队交付可复盘可审计”，STEP 的当前实现更完整。
