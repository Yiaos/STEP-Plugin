# Unify SKILL.md and WORKFLOW.md Lite e2e test requirements

```json task
{
  "id": "unify-e2e-rule",
  "title": "Unify SKILL.md and WORKFLOW.md Lite e2e test requirements",
  "mode": "full",
  "status": "done",
  "depends_on": [],
  "goal": "消除 SKILL.md 内部及 SKILL.md 与 WORKFLOW.md 之间关于 Lite 模式 e2e 测试要求的矛盾。统一为：unit/integration 必须，e2e Full 必须 Lite 按需。",
  "non_goal": [
    "不修改 Full 模式的测试要求",
    "不修改 scenario-check.sh 脚本逻辑"
  ],
  "done_when": [
    "bash tests/test-e2e-rule-consistency.sh"
  ],
  "scenarios": {
    "happy_path": [
      {
        "id": "S-unify-e2e-rule-01",
        "given": "SKILL.md 和 WORKFLOW.md 存在",
        "when": "grep 搜索 e2e 相关规则",
        "then": "所有出现的 e2e 规则表述一致：Full 必须，Lite 按需",
        "test_file": "tests/test-e2e-rule-consistency.sh",
        "test_name": "[S-unify-e2e-rule-01] e2e rule consistent across docs",
        "test_type": "integration",
        "status": "pass"
      }
    ],
    "edge_cases": [
      {
        "id": "S-unify-e2e-rule-02",
        "given": "SKILL.md 硬规则列表",
        "when": "检查第 6 条规则",
        "then": "明确区分 Full/Lite 的 e2e 要求",
        "test_file": "tests/test-e2e-rule-consistency.sh",
        "test_name": "[S-unify-e2e-rule-02] rule 6 distinguishes Full vs Lite",
        "test_type": "unit",
        "status": "pass"
      }
    ],
    "error_handling": [
      {
        "id": "S-unify-e2e-rule-03",
        "given": "未来有人修改 e2e 规则",
        "when": "运行一致性测试",
        "then": "如果不一致则测试失败",
        "test_file": "tests/test-e2e-rule-consistency.sh",
        "test_name": "[S-unify-e2e-rule-03] inconsistency detected by test",
        "test_type": "e2e",
        "status": "pass"
      }
    ]
  },
  "coverage_requirements": {
    "happy_path": "1+",
    "edge_cases": "1+",
    "error_handling": "1+",
    "security": "as_needed"
  },
  "rollback": "git revert --no-commit HEAD~1"
}
```
