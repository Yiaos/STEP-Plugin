```json task
{
  "id": "task-slug",
  "title": "Task title",
  "mode": "full",
  "status": "planned",
  "depends_on": [],
  "goal": "One-line task goal",
  "non_goal": [
    "What is out of scope"
  ],
  "done_when": [
    "pnpm lint",
    "pnpm tsc --noEmit",
    "pnpm vitest run test/xxx/xxx.test.ts"
  ],
  "scenarios": {
    "happy_path": [
      {
        "id": "S-task-slug-01",
        "given": "Normal input",
        "when": "Execute action",
        "then": "Expected output",
        "test_file": "test/xxx/xxx.test.ts",
        "test_name": "[S-task-slug-01] Description",
        "test_type": "unit",
        "status": "not_run"
      }
    ],
    "edge_cases": [
      {
        "id": "S-task-slug-02",
        "given": "Boundary input",
        "when": "Execute action",
        "then": "Expected output",
        "test_file": "test/xxx/xxx.test.ts",
        "test_name": "[S-task-slug-02] Description",
        "test_type": "unit",
        "status": "not_run"
      }
    ],
    "error_handling": [
      {
        "id": "S-task-slug-03",
        "given": "Invalid input or environment",
        "when": "Execute action",
        "then": "Expected error handling",
        "test_file": "test/xxx/xxx.test.ts",
        "test_name": "[S-task-slug-03] Description",
        "test_type": "integration",
        "status": "not_run"
      }
    ]
  },
  "coverage_requirements": {
    "happy_path": "1+",
    "edge_cases": "2+",
    "error_handling": "1+",
    "security": "as_needed"
  },
  "rollback": "git revert --no-commit HEAD~N"
}
```
