# Add change cancel/abort mechanism

```json task
{
  "id": "cancel-mechanism",
  "title": "Add change cancel/abort mechanism",
  "mode": "full",
  "status": "done",
  "depends_on": [
    "manager-core-migrate"
  ],
  "goal": "新增 manager cancel 子命令，支持用户放弃当前变更。变更归档到 .step/archive/ 加 -cancelled 后缀。",
  "non_goal": [
    "不自动删除已写入的代码文件",
    "不修改正常归档流程"
  ],
  "done_when": [
    "bash tests/test-cancel-mechanism.sh",
    "step-core.js manager cancel 可将 phase 重置为 idle",
    "取消的变更归档到 .step/archive/YYYY-MM-DD-{name}-cancelled/"
  ],
  "scenarios": {
    "happy_path": [
      {
        "id": "S-cancel-mechanism-01",
        "given": "phase 为 phase-2-design，current_change 为 test-change",
        "when": "执行 manager cancel",
        "then": "phase 重置为 idle，current_change 清空，progress_log 记录取消",
        "test_file": "tests/test-cancel-mechanism.sh",
        "test_name": "[S-cancel-mechanism-01] cancel resets state to idle",
        "test_type": "integration",
        "status": "pass"
      },
      {
        "id": "S-cancel-mechanism-02",
        "given": "phase 为 phase-3-plan，变更目录存在",
        "when": "执行 manager cancel",
        "then": "变更目录移动到 .step/archive/{date}-{name}-cancelled/",
        "test_file": "tests/test-cancel-mechanism.sh",
        "test_name": "[S-cancel-mechanism-02] cancelled change archived with suffix",
        "test_type": "integration",
        "status": "pass"
      }
    ],
    "edge_cases": [
      {
        "id": "S-cancel-mechanism-03",
        "given": "phase 为 idle（无活跃变更）",
        "when": "执行 manager cancel",
        "then": "输出提示无活跃变更，退出码 0",
        "test_file": "tests/test-cancel-mechanism.sh",
        "test_name": "[S-cancel-mechanism-03] cancel when idle is no-op",
        "test_type": "unit",
        "status": "pass"
      },
      {
        "id": "S-cancel-mechanism-04",
        "given": "phase 为 done",
        "when": "执行 manager cancel",
        "then": "拒绝取消已完成的变更，退出码非 0",
        "test_file": "tests/test-cancel-mechanism.sh",
        "test_name": "[S-cancel-mechanism-04] cannot cancel done change",
        "test_type": "unit",
        "status": "pass"
      }
    ],
    "error_handling": [
      {
        "id": "S-cancel-mechanism-05",
        "given": "变更目录不存在（已被手动删除）",
        "when": "执行 manager cancel",
        "then": "仅重置 state，跳过归档，不崩溃",
        "test_file": "tests/test-cancel-mechanism.sh",
        "test_name": "[S-cancel-mechanism-05] missing change dir handled",
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
