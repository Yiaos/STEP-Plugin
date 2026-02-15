---
description: "归档已完成的 STEP 任务。将 .step/tasks/ 中状态为 done 的任务移到 .step/archive/。"
---

归档已完成的 STEP 任务。

## 用法

- `/archive` — 交互式：列出所有 done 状态的任务，确认后归档
- `/archive all` — 归档所有 done 状态的任务
- `/archive {slug}` — 归档指定任务（如 `/archive user-register-api`）

## 执行逻辑

1. 如果指定了 `all` 参数：
   - 运行 `bash ~/.config/opencode/tools/step/scripts/step-archive.sh --all`
   - 报告归档结果

2. 如果指定了具体 slug：
   - 运行 `bash ~/.config/opencode/tools/step/scripts/step-archive.sh {slug}`
   - 报告归档结果

3. 如果没有参数：
   - 列出 `.step/tasks/` 中所有 `status: done` 的任务
   - 显示列表，询问用户是否要归档全部或选择性归档
   - 用户确认后执行归档

## 归档后

- 更新 `.step/state.yaml` 的 `tasks.completed` 列表（如需要）
- 报告: "✅ 已归档 N 个任务到 .step/archive/"
