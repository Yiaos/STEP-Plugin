# Design: Apply Two-Action Rule to Findings

## 方案
采用文档规则 + 测试守护的轻量实现：

1. 在 `skills/step/SKILL.md` 的 Phase 0/2 规则中明确 2-action rule。
2. 在 `WORKFLOW.md` 的 findings 章节补充执行细则。
3. 在 `templates/findings.md` 添加固定检查点模板，便于实际填写。
4. 新增测试 `tests/test-findings-two-action-rule.sh`，并加入 gate.test。

## 规则定义
- 有效探索动作：阅读文件、检索、调研、分析性命令等。
- 每累计 2 个有效动作，需在 findings 记录：
  - 新事实/约束；或
  - 明确写“本轮无新增发现”。

## 风险
- 仅文档级约束，无法技术上精确计数动作。
- 通过测试与 reviewer 约束降低漂移风险。
