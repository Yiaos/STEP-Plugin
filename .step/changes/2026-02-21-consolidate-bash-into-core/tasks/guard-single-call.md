# Consolidate pretool-guard into single Node call

```json task
{
  "id": "guard-single-call",
  "title": "Consolidate pretool-guard into single Node call",
  "mode": "full",
  "status": "done",
  "depends_on": [
    "manager-core-migrate"
  ],
  "goal": "step-pretool-guard.sh 改为单次 Node 调用（step-core.js guard 子命令），从 4-5 个 Node 进程降为 1 个。",
  "non_goal": [
    "不改变 PreToolUse Hook 的外部行为（允许/拒绝语义不变）",
    "不引入常驻 Node 进程"
  ],
  "done_when": [
    "bash tests/test-step-pretool-guard.sh",
    "bash tests/test-step-manager-check-action.sh",
    "step-pretool-guard.sh 中 node 调用次数 <= 1"
  ],
  "scenarios": {
    "happy_path": [
      {
        "id": "S-guard-single-call-01",
        "given": "phase 为 phase-4-execution，tool 为 Write",
        "when": "执行 guard 子命令",
        "then": "退出码 0，输出 state 摘要",
        "test_file": "tests/test-step-pretool-guard.sh",
        "test_name": "[S-guard-single-call-01] write allowed in phase-4",
        "test_type": "integration",
        "status": "pass"
      },
      {
        "id": "S-guard-single-call-02",
        "given": "phase 为 idle，auto-enter 启用",
        "when": "执行 guard 子命令",
        "then": "自动进入对应 phase，退出码 0",
        "test_file": "tests/test-step-pretool-guard.sh",
        "test_name": "[S-guard-single-call-02] auto-enter from idle",
        "test_type": "integration",
        "status": "pass"
      }
    ],
    "edge_cases": [
      {
        "id": "S-guard-single-call-03",
        "given": "phase 为 phase-1-prd，tool 为 Write",
        "when": "执行 guard 子命令",
        "then": "退出码非 0，拒绝写操作（规划阶段写锁）",
        "test_file": "tests/test-step-pretool-guard.sh",
        "test_name": "[S-guard-single-call-03] write blocked in planning phase",
        "test_type": "integration",
        "status": "pass"
      },
      {
        "id": "S-guard-single-call-04",
        "given": "phase 为 phase-4-execution，tool 为 Bash，command 含 rm -rf",
        "when": "执行 guard 子命令",
        "then": "退出码非 0，拒绝危险命令",
        "test_file": "tests/test-step-manager-check-action.sh",
        "test_name": "[S-guard-single-call-04] dangerous bash blocked",
        "test_type": "unit",
        "status": "pass"
      }
    ],
    "error_handling": [
      {
        "id": "S-guard-single-call-05",
        "given": ".step/state.json 不存在",
        "when": "执行 guard 子命令",
        "then": "退出码 0（无 state 时不阻断）",
        "test_file": "tests/test-step-pretool-guard.sh",
        "test_name": "[S-guard-single-call-05] no state file passes through",
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
