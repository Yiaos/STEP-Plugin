```json task
{
  "id": "stabilize-step-trigger-enforcement",
  "title": "Stabilize STEP trigger and enforcement",
  "mode": "full",
  "status": "done",
  "depends_on": [],
  "goal": "实现 step-manager 统一入口并将 Bash 黑名单能力扩展到非 gate 调用路径。",
  "non_goal": [
    "不重构全部 gate 内核",
    "不引入外部依赖"
  ],
  "done_when": [
    "bash scripts/step-manager.sh doctor",
    "bash tests/test-step-manager-check-action.sh",
    "bash tests/test-gate-dangerous-executable.sh"
  ],
  "scenarios": {
    "happy_path": [
      {
        "id": "S-stabilize-step-trigger-enforcement-01",
        "given": "step-manager 可用",
        "when": "执行 step-manager doctor",
        "then": "返回 PASS 并退出码为 0",
        "test_file": "tests/test-step-manager-check-action.sh",
        "test_name": "[S-stabilize-step-trigger-enforcement-01] step-manager doctor health pass",
        "test_type": "unit",
        "status": "not_run"
      },
      {
        "id": "S-stabilize-step-trigger-enforcement-02",
        "given": "Bash 命令命中黑名单",
        "when": "执行 step-manager check-action --tool Bash --command",
        "then": "返回非 0 并输出阻断信息",
        "test_file": "tests/test-step-manager-check-action.sh",
        "test_name": "[S-stabilize-step-trigger-enforcement-02] check-action blocks dangerous command",
        "test_type": "integration",
        "status": "not_run"
      }
    ],
    "edge_cases": [
      {
        "id": "S-stabilize-step-trigger-enforcement-03",
        "given": "check-action 传入空 command",
        "when": "执行 Bash 检查",
        "then": "不误拦截并返回 0",
        "test_file": "tests/test-step-manager-check-action.sh",
        "test_name": "[S-stabilize-step-trigger-enforcement-03] empty command allowed",
        "test_type": "unit",
        "status": "not_run"
      }
    ],
    "error_handling": [
      {
        "id": "S-stabilize-step-trigger-enforcement-04",
        "given": "缺失 .step/config.json",
        "when": "执行 check-action Bash 检查",
        "then": "使用默认黑名单兜底",
        "test_file": "tests/test-step-manager-check-action.sh",
        "test_name": "[S-stabilize-step-trigger-enforcement-04] fallback dangerous list",
        "test_type": "e2e",
        "status": "not_run"
      }
    ]
  },
  "coverage_requirements": {
    "happy_path": "1+",
    "edge_cases": "1+",
    "error_handling": "1+",
    "security": "required"
  },
  "rollback": "git revert --no-commit HEAD~1"
}
```
