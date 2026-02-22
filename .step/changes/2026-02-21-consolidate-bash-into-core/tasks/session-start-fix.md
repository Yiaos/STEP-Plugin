# Fix session-start.sh $ escape bug via Node JSON generation

```json task
{
  "id": "session-start-fix",
  "title": "Fix session-start.sh $ escape bug via Node JSON generation",
  "mode": "full",
  "status": "done",
  "depends_on": [
    "manager-core-migrate"
  ],
  "goal": "session-start.sh 的 JSON 输出改为 step-core.js hook session-start 子命令生成，消除 $ 变量展开 bug。",
  "non_goal": [
    "不改变 Hook 输出的 JSON 结构",
    "不实现按 phase 分级注入（留给 task-6）"
  ],
  "done_when": [
    "bash tests/test-session-start-hook.sh",
    "session-start.sh 不含 escape_for_json 函数",
    "session-start.sh 不含 cat <<EOF 拼接 JSON"
  ],
  "scenarios": {
    "happy_path": [
      {
        "id": "S-session-start-fix-01",
        "given": ".step/state.json 存在且 phase 为 phase-4-execution",
        "when": "执行 hook session-start",
        "then": "输出合法 JSON，包含 state/spec/task/baseline/skill 内容",
        "test_file": "tests/test-session-start-hook.sh",
        "test_name": "[S-session-start-fix-01] hook outputs valid JSON with all sections",
        "test_type": "integration",
        "status": "pass"
      },
      {
        "id": "S-session-start-fix-02",
        "given": "baseline.md 包含 $HOME 和 $(date) 文本",
        "when": "执行 hook session-start",
        "then": "输出 JSON 中 $HOME 和 $(date) 原样保留，未被 Bash 展开",
        "test_file": "tests/test-session-start-hook.sh",
        "test_name": "[S-session-start-fix-02] dollar signs preserved in output",
        "test_type": "unit",
        "status": "pass"
      }
    ],
    "edge_cases": [
      {
        "id": "S-session-start-fix-03",
        "given": ".step/state.json 不存在",
        "when": "执行 session-start.sh",
        "then": "输出空 JSON 或跳过，退出码 0",
        "test_file": "tests/test-session-start-hook.sh",
        "test_name": "[S-session-start-fix-03] missing state exits gracefully",
        "test_type": "unit",
        "status": "pass"
      },
      {
        "id": "S-session-start-fix-04",
        "given": "spec.md 包含 JSON 特殊字符（换行、引号、反斜杠）",
        "when": "执行 hook session-start",
        "then": "输出 JSON 合法，特殊字符正确转义",
        "test_file": "tests/test-session-start-hook.sh",
        "test_name": "[S-session-start-fix-04] special chars escaped correctly",
        "test_type": "unit",
        "status": "pass"
      }
    ],
    "error_handling": [
      {
        "id": "S-session-start-fix-05",
        "given": "state.json 存在但 JSON 格式损坏",
        "when": "执行 hook session-start",
        "then": "输出降级内容（原始文本），不崩溃",
        "test_file": "tests/test-session-start-hook.sh",
        "test_name": "[S-session-start-fix-05] corrupted state handled gracefully",
        "test_type": "integration",
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
