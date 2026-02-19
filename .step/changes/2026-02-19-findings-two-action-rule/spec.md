# Spec: Findings Two-Action Rule

## 背景
Phase 0/2 的探索信息容易在多轮对话中丢失，导致重复调研与决策依据断层。

## 目标
为 findings 增加类似 planning-with-files 的 `2-action rule`：
- 在 Discovery/Tech Design 阶段，每完成 2 个有效探索动作后，必须更新 findings。

## 非目标
- 不做复杂脚本统计动作次数。
- 不引入外部依赖。

## 验收标准
- `SKILL.md`、`WORKFLOW.md`、`templates/findings.md` 都包含 2-action rule 描述。
- 新增测试校验规则存在并纳入 gate.test。
