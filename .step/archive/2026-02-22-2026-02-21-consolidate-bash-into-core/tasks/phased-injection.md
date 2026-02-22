# SessionStart phase-based context injection

```json task
{
  "id": "phased-injection",
  "title": "SessionStart phase-based context injection",
  "mode": "full",
  "status": "done",
  "depends_on": [
    "session-start-fix"
  ],
  "goal": "SKILL.md 增加分段标记，hook session-start 按当前 phase 裁剪注入内容，Phase 4 注入量减少约 40%。",
  "non_goal": [
    "不修改 SKILL.md 的实际规则内容",
    "不改变 Hook 输出 JSON 结构"
  ],
  "done_when": [
    "bash tests/test-session-start-hook.sh",
    "SKILL.md 包含 SECTION:core-rules / SECTION:phase-0-1 / SECTION:phase-2-3 / SECTION:phase-4-5 / SECTION:common 标记",
    "phase-4-execution 时注入内容不含 Phase 0/1/2/3 规则段落"
  ],
  "scenarios": {
    "happy_path": [
      {
        "id": "S-phased-injection-01",
        "given": "phase 为 phase-4-execution",
        "when": "执行 hook session-start",
        "then": "输出包含 core-rules + phase-4-5 + common，不含 phase-0-1 和 phase-2-3",
        "test_file": "tests/test-session-start-hook.sh",
        "test_name": "[S-phased-injection-01] phase-4 gets only relevant sections",
        "test_type": "integration",
        "status": "pass"
      },
      {
        "id": "S-phased-injection-02",
        "given": "phase 为 phase-1-prd",
        "when": "执行 hook session-start",
        "then": "输出包含 core-rules + phase-0-1 + common，不含 phase-2-3 和 phase-4-5",
        "test_file": "tests/test-session-start-hook.sh",
        "test_name": "[S-phased-injection-02] phase-1 gets only relevant sections",
        "test_type": "integration",
        "status": "pass"
      }
    ],
    "edge_cases": [
      {
        "id": "S-phased-injection-03",
        "given": "phase 为 idle",
        "when": "执行 hook session-start",
        "then": "输出包含 core-rules + common（最小集）",
        "test_file": "tests/test-session-start-hook.sh",
        "test_name": "[S-phased-injection-03] idle gets minimal sections",
        "test_type": "unit",
        "status": "pass"
      },
      {
        "id": "S-phased-injection-04",
        "given": "SKILL.md 缺少某个 SECTION 标记",
        "when": "执行 hook session-start",
        "then": "降级为注入全文，不崩溃",
        "test_file": "tests/test-session-start-hook.sh",
        "test_name": "[S-phased-injection-04] missing section marker falls back to full",
        "test_type": "unit",
        "status": "pass"
      }
    ],
    "error_handling": [
      {
        "id": "S-phased-injection-05",
        "given": "SKILL.md 文件不存在",
        "when": "执行 hook session-start",
        "then": "跳过 skill 注入，其余内容正常输出",
        "test_file": "tests/test-session-start-hook.sh",
        "test_name": "[S-phased-injection-05] missing skill file handled",
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
