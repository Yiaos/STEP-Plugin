# Migrate step-manager.sh logic to step-core.js manager subcommand

```json task
{
  "id": "manager-core-migrate",
  "title": "Migrate step-manager.sh logic to step-core.js manager subcommand",
  "mode": "full",
  "status": "done",
  "depends_on": [],
  "goal": "将 step-manager.sh 的 14 个函数迁移到 step-core.js manager 子命令，step-manager.sh 改为薄壳。",
  "non_goal": [
    "不修改 step-manager.sh 的命令行接口",
    "不拆分 step-core.js 为多文件"
  ],
  "done_when": [
    "bash tests/test-step-manager-check-action.sh",
    "bash tests/test-step-phase-enforcement.sh",
    "bash tests/test-phase-gate-requirements.sh",
    "bash tests/test-lite-mode-and-naming.sh",
    "step-manager.sh 行数 < 30"
  ],
  "scenarios": {
    "happy_path": [
      {
        "id": "S-manager-core-migrate-01",
        "given": "step-core.js manager enter --mode full --change test-change",
        "when": "执行命令",
        "then": "state.json 的 current_phase 设为 phase-1-prd，current_change 设为 test-change",
        "test_file": "tests/test-step-phase-enforcement.sh",
        "test_name": "[S-manager-core-migrate-01] manager enter sets phase and change",
        "test_type": "integration",
        "status": "pass"
      },
      {
        "id": "S-manager-core-migrate-02",
        "given": "当前 phase 为 phase-1-prd",
        "when": "执行 step-core.js manager transition --to phase-2-design",
        "then": "state.json 的 current_phase 更新为 phase-2-design",
        "test_file": "tests/test-step-phase-enforcement.sh",
        "test_name": "[S-manager-core-migrate-02] manager transition updates phase",
        "test_type": "integration",
        "status": "pass"
      }
    ],
    "edge_cases": [
      {
        "id": "S-manager-core-migrate-03",
        "given": "当前 phase 为 phase-1-prd",
        "when": "执行 manager transition --to phase-4-execution（跳阶段）",
        "then": "退出码非 0，state 不变",
        "test_file": "tests/test-step-phase-enforcement.sh",
        "test_name": "[S-manager-core-migrate-03] invalid transition rejected",
        "test_type": "integration",
        "status": "pass"
      },
      {
        "id": "S-manager-core-migrate-04",
        "given": "step-manager.sh 已改为薄壳",
        "when": "通过 step-manager.sh enter/transition/assert-phase 调用",
        "then": "行为与直接调用 step-core.js manager 一致",
        "test_file": "tests/test-step-phase-enforcement.sh",
        "test_name": "[S-manager-core-migrate-04] thin shell delegates correctly",
        "test_type": "integration",
        "status": "pass"
      }
    ],
    "error_handling": [
      {
        "id": "S-manager-core-migrate-05",
        "given": ".step/state.json 不存在",
        "when": "执行 manager status-line",
        "then": "输出 idle 状态，退出码 0",
        "test_file": "tests/test-step-phase-enforcement.sh",
        "test_name": "[S-manager-core-migrate-05] missing state handled gracefully",
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
