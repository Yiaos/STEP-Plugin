# STEP Examples

本文件收录 WORKFLOW 的示例性内容（对话样例、Lite 批量任务样例、Post-MVP 场景样例）。

## Lite Mode Example

```
L1 Quick Spec  -> L2 Execution -> L3 Review
```

- L1 Quick Spec：一次确认
- L2 Execution：TDD + gate
- L3 Review：完整 Code Review（需求合规 > 代码质量）

## Lite Batch Example

用户一次提交多个小任务时：

- fix-empty-password
- adjust-button-position
- add-loading-animation

批量确认后逐个执行，每个任务独立完成 TDD + gate + review。

## Post-MVP 示例

- 新增功能：`changes/YYYY-MM-DD-{slug}/`
- Hotfix：`changes/YYYY-MM-DD-{slug}-hotfix/`
- 约束变更：先影响分析，再迁移任务
