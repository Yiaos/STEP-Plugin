# Optimize findings 2-Action Rule execution cost

```json task
{
  "id": "optimize-two-action-rule",
  "title": "Optimize findings 2-Action Rule execution cost",
  "mode": "full",
  "status": "done",
  "depends_on": [],
  "goal": "降低 2-Action Rule 的执行成本：将固定的每 2 动作强制更新改为分级策略——Phase 0 Discovery 保持每 2 动作更新，其他阶段改为每 4 动作或有实质发现时更新。消除无意义的'本轮无新增发现'记录。",
  "non_goal": [
    "不取消 findings 机制本身",
    "不修改 findings.md 文件格式",
    "不修改 scenario-check.sh"
  ],
  "done_when": [
    "bash tests/test-findings-two-action-rule.sh",
    "SKILL.md 中 2-Action Rule 描述更新为分级策略",
    "WORKFLOW.md 中对应描述一致",
    "step-stop-check.sh 中 findings 检查逻辑按 phase 区分阈值"
  ],
  "scenarios": {
    "happy_path": [
      {
        "id": "S-optimize-2ar-01",
        "given": "phase 为 phase-0-discovery，已执行 2 个探索动作",
        "when": "stop-check 检查 findings 更新",
        "then": "要求更新 findings（阈值=2）",
        "test_file": "tests/test-findings-two-action-rule.sh",
        "test_name": "[S-optimize-2ar-01] phase-0 keeps 2-action threshold",
        "test_type": "integration",
        "status": "pass"
      },
      {
        "id": "S-optimize-2ar-02",
        "given": "phase 为 phase-4-execution，已执行 3 个动作",
        "when": "stop-check 检查 findings 更新",
        "then": "不要求更新（阈值=4）",
        "test_file": "tests/test-findings-two-action-rule.sh",
        "test_name": "[S-optimize-2ar-02] phase-4 uses 4-action threshold",
        "test_type": "integration",
        "status": "pass"
      }
    ],
    "edge_cases": [
      {
        "id": "S-optimize-2ar-03",
        "given": "phase 为 phase-4-execution，已执行 4 个动作",
        "when": "stop-check 检查 findings 更新",
        "then": "要求更新 findings（达到阈值=4）",
        "test_file": "tests/test-findings-two-action-rule.sh",
        "test_name": "[S-optimize-2ar-03] phase-4 triggers at threshold 4",
        "test_type": "unit",
        "status": "pass"
      },
      {
        "id": "S-optimize-2ar-04",
        "given": "Lite 模式 lite-l2",
        "when": "stop-check 检查 findings 更新",
        "then": "使用 4-action 阈值（Lite 执行阶段）",
        "test_file": "tests/test-findings-two-action-rule.sh",
        "test_name": "[S-optimize-2ar-04] lite-l2 uses relaxed threshold",
        "test_type": "unit",
        "status": "pass"
      }
    ],
    "error_handling": [
      {
        "id": "S-optimize-2ar-05",
        "given": "state.json 中 current_phase 为空或无法识别",
        "when": "stop-check 检查 findings 更新",
        "then": "回退到默认阈值 2（保守策略）",
        "test_file": "tests/test-findings-two-action-rule.sh",
        "test_name": "[S-optimize-2ar-05] unknown phase falls back to threshold 2",
        "test_type": "unit",
        "status": "pass"
      }
    ]
  },
  "coverage_requirements": {
    "happy_path": "2+",
    "edge_cases": "2+",
    "error_handling": "1+",
    "security": "as_needed"
  },
  "rollback": "git revert --no-commit HEAD~N"
}
```
