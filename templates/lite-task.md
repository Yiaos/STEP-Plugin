```json task
{
  "id": "task-slug",
  "title": "Task title",
  "mode": "lite",
  "status": "planned",
  "created": "",
  "parent_baseline": ".step/baseline.md",
  "goal": "One-line task goal",
  "non_goal": [
    "What is out of scope"
  ],
  "affected_files": [
    "src/xxx/xxx.ts"
  ],
  "scenarios": [
    {
      "id": "S-task-slug-01",
      "given": "Normal input",
      "when": "Execute action",
      "then": "Expected output",
      "test_file": "test/xxx/xxx.test.ts",
      "test_name": "[S-task-slug-01] Description",
      "test_type": "unit",
      "status": "not_run"
    },
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
  "done_when": [
    "gate.sh lite task-slug"
  ]
}
```
