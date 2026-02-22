# Deduplicate task_status_is into step-core.js task status

```json task
{
  "id": "dedup-task-status",
  "title": "Deduplicate task_status_is into step-core.js task status",
  "mode": "full",
  "status": "done",
  "depends_on": [
    "manager-core-migrate"
  ],
  "goal": "消除 step-archive.sh、step-worktree.sh、step-stop-check.sh 中 task_status_is 的重复定义，统一为 step-core.js task status 子命令。",
  "non_goal": [
    "不修改 task 文件格式",
    "不修改 archive/worktree/stop-check 的外部行为"
  ],
  "done_when": [
    "bash tests/test-step-archive.sh",
    "bash tests/test-step-stop-check.sh",
    "grep -c 'task_status_is' scripts/step-archive.sh scripts/step-worktree.sh scripts/step-stop-check.sh 中每个文件的内联 node -e 为 0"
  ],
  "scenarios": {
    "happy_path": [
      {
        "id": "S-dedup-task-status-01",
        "given": "task 文件 status 为 done",
        "when": "执行 step-core.js task status --file <path> --expected done",
        "then": "退出码 0",
        "test_file": "tests/test-step-archive.sh",
        "test_name": "[S-dedup-task-status-01] task status matches expected",
        "test_type": "unit",
        "status": "pass"
      },
      {
        "id": "S-dedup-task-status-02",
        "given": "task 文件 status 为 in_progress",
        "when": "执行 step-core.js task status --file <path> --expected done",
        "then": "退出码 1",
        "test_file": "tests/test-step-archive.sh",
        "test_name": "[S-dedup-task-status-02] task status mismatch returns 1",
        "test_type": "unit",
        "status": "pass"
      }
    ],
    "edge_cases": [
      {
        "id": "S-dedup-task-status-03",
        "given": "task 文件为 .md 格式（含 json 代码块）",
        "when": "执行 task status",
        "then": "正确解析 markdown 中的 JSON 并返回 status",
        "test_file": "tests/test-step-archive.sh",
        "test_name": "[S-dedup-task-status-03] md format task parsed correctly",
        "test_type": "unit",
        "status": "pass"
      }
    ],
    "error_handling": [
      {
        "id": "S-dedup-task-status-04",
        "given": "task 文件不存在",
        "when": "执行 task status --file nonexistent.md --expected done",
        "then": "退出码 2（解析失败）",
        "test_file": "tests/test-step-archive.sh",
        "test_name": "[S-dedup-task-status-04] missing file returns exit 2",
        "test_type": "unit",
        "status": "pass"
      }
    ]
  },
  "coverage_requirements": {
    "happy_path": "2+",
    "edge_cases": "1+",
    "error_handling": "1+",
    "security": "as_needed"
  },
  "rollback": "git revert --no-commit HEAD~N"
}
```
