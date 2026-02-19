```json task
{
  "id": "findings-two-action-rule",
  "title": "Add findings two-action rule",
  "mode": "full",
  "status": "done",
  "depends_on": [],
  "goal": "在 STEP 中落地 findings 的 2-action rule 并加测试守护。",
  "done_when": [
    "bash tests/test-findings-two-action-rule.sh"
  ],
  "scenarios": {
    "happy_path": [
      {
        "id": "S-findings-two-action-rule-01",
        "given": "Phase 0/2 文档存在",
        "when": "读取 SKILL/WORKFLOW/template",
        "then": "均出现 2-action rule 描述",
        "test_file": "tests/test-findings-two-action-rule.sh",
        "test_name": "[S-findings-two-action-rule-01] findings 2-action rule documented",
        "test_type": "integration",
        "status": "not_run"
      }
    ],
    "edge_cases": [
      {
        "id": "S-findings-two-action-rule-02",
        "given": "gate 执行",
        "when": "运行 gate.test",
        "then": "包含本测试",
        "test_file": "tests/test-findings-two-action-rule.sh",
        "test_name": "[S-findings-two-action-rule-02] gate includes findings rule test",
        "test_type": "unit",
        "status": "not_run"
      }
    ],
    "error_handling": [
      {
        "id": "S-findings-two-action-rule-03",
        "given": "规则被误删",
        "when": "执行测试",
        "then": "测试失败并阻断",
        "test_file": "tests/test-findings-two-action-rule.sh",
        "test_name": "[S-findings-two-action-rule-03] missing rule fails tests",
        "test_type": "e2e",
        "status": "not_run"
      }
    ]
  }
}
```
