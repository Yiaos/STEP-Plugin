# Spec: Stabilize STEP Trigger & Enforcement

## 背景
当前 STEP 已具备可用环境检查（doctor）与 gate/stop 机制，但仍存在两类稳定性风险：
- 触发稳定性不足：环境 PASS 不等于进入流程执行态，`idle` 状态下仍可能发生“看起来在执行 STEP”的误判。
- 约束稳定性不足：危险命令黑名单主要在 gate 链路生效，常规 Bash 不在统一拦截域内。

## 目标
1. 统一入口：建立 `step-manager` 作为 doctor/check-action 的统一命令面。
2. 统一约束：将 Bash 黑名单能力从 gate 专用升级为“全局 Bash 预检查可复用能力”。
3. 明确状态：执行前能区分“环境就绪”和“流程执行中”，避免 `idle` 误执行。

## 非目标
- 不改业务功能。
- 不引入第三方依赖（npm/pip 包）。
- 不重构全部 STEP 脚本，仅落地触发与约束稳定性的 P0 能力。

## 验收标准
- `/step` 语义入口可通过 `step-manager doctor` 统一调用 doctor。
- `step-manager check-action --tool Bash --command "..."` 对黑名单命令返回非 0。
- 非 gate 的 Bash 调用可接入同一黑名单能力（通过 PreToolUse 调用 `step-manager check-action`）。
- gate 现有黑名单能力保持兼容，不被删除。
