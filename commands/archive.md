---
description: "归档已完成的 STEP 变更。将 .step/changes/ 中已完成的变更文件夹移到 .step/archive/。"
---

归档已完成的 STEP 变更。

## 用法

- `/archive` — 交互式：列出所有已完成变更，确认后归档
- `/archive {change-name}` — 归档指定变更（如 `/archive init` 或 `/archive 2026-02-20-add-dark-mode`）

## 执行逻辑

1. 检查 `.step/changes/` 下所有变更文件夹
2. 对于每个变更，检查其 `tasks/` 下所有任务是否都是 `status: done`
3. 全部完成的变更可归档：
   - 移动整个变更文件夹到 `.step/archive/YYYY-MM-DD-{change-name}/`
   - 更新 baseline.md 反映最新状态
4. 报告归档结果

## 归档后

- 更新 `.step/state.json`：清空 `current_change`（如果归档的是当前变更）
- 更新 `.step/baseline.md`：变更完成后 baseline 反映最新状态
- 报告: "✅ 已归档变更 {name} 到 .step/archive/"
