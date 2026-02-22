# STEP Hooks and Commands

本文件收录 Hook 与命令实现细节。

## SessionStart

- `hooks/session-start.sh`
- 调用 `step-core.js hook session-start`
- 注入 state/spec/findings/task/baseline/config/skill（按 phase 裁剪）

## PreToolUse

- `scripts/step-pretool-guard.sh`
- 调用 `step-core.js guard`
- 执行 phase 校验、dispatch 校验、危险命令检查、auto-enter

## Stop

- `scripts/step-stop-check.sh`
- 检查 state 更新时间、progress_log、gate 失败记录完整性

## Commands

- `/step`：初始化或恢复 STEP
- `/step/status`：查看 phase/change/task/gate/evidence
- `/archive`：归档 completed change

## AGENTS.md 模板说明

AGENTS.md 应只做导航，不复制 baseline 细节。冲突优先级：

1. baseline 冲突：以 `.step/baseline.md` 为准
2. 流程冲突：以 `.step/state.json` 为准
3. 执行冲突：以脚本运行结果为准
