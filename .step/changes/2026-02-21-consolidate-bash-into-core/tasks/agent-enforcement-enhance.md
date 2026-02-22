# Enhance agent dispatch enforcement in pretool guard

```json task
{
  "id": "agent-enforcement-enhance",
  "title": "Enhance agent dispatch enforcement in pretool guard",
  "mode": "full",
  "status": "done",
  "depends_on": [
    "guard-single-call"
  ],
  "goal": "增强角色 Agent 约束力：Phase 4 执行阶段，当 config 中 require_dispatch=true 时，guard 拦截非 Task 的 Write/Edit 调用（强制通过 subagent 写代码）。增加 bypass 白名单机制供用户豁免。",
  "non_goal": [
    "不修改 agent .md 文件的 prompt 内容",
    "不强制 Lite 模式使用 dispatch",
    "不拦截 Bash/Read 等只读操作"
  ],
  "done_when": [
    "bash tests/test-agent-enforcement.sh",
    "Full 模式 Phase 4 下直接 Write/Edit 被 guard 拦截（require_dispatch=true 时）",
    "config.json 中 enforcement.bypass_tools 白名单可豁免特定操作",
    "Lite 模式不受影响"
  ],
  "scenarios": {
    "happy_path": [
      {
        "id": "S-agent-enforce-01",
        "given": "Full 模式 phase-4-execution，require_dispatch=true",
        "when": "guard 收到 Write 工具调用（非 subagent 上下文）",
        "then": "拒绝并提示应通过 developer agent 执行",
        "test_file": "tests/test-agent-enforcement.sh",
        "test_name": "[S-agent-enforce-01] direct write blocked in full mode phase-4",
        "test_type": "integration",
        "status": "pass"
      },
      {
        "id": "S-agent-enforce-02",
        "given": "Full 模式 phase-4-execution，require_dispatch=true",
        "when": "guard 收到 Task 工具调用，agent=step-developer",
        "then": "允许通过",
        "test_file": "tests/test-agent-enforcement.sh",
        "test_name": "[S-agent-enforce-02] task dispatch to developer allowed",
        "test_type": "integration",
        "status": "pass"
      }
    ],
    "edge_cases": [
      {
        "id": "S-agent-enforce-03",
        "given": "Full 模式 phase-4-execution，bypass_tools 包含 Write",
        "when": "guard 收到 Write 工具调用",
        "then": "允许通过（白名单豁免）",
        "test_file": "tests/test-agent-enforcement.sh",
        "test_name": "[S-agent-enforce-03] bypass whitelist allows write",
        "test_type": "unit",
        "status": "pass"
      },
      {
        "id": "S-agent-enforce-04",
        "given": "Lite 模式 lite-l2，require_dispatch=true",
        "when": "guard 收到 Write 工具调用",
        "then": "允许通过（Lite 模式不强制 dispatch）",
        "test_file": "tests/test-agent-enforcement.sh",
        "test_name": "[S-agent-enforce-04] lite mode bypasses dispatch check",
        "test_type": "unit",
        "status": "pass"
      }
    ],
    "error_handling": [
      {
        "id": "S-agent-enforce-05",
        "given": "config.json 中 enforcement 字段缺失",
        "when": "guard 执行 dispatch 检查",
        "then": "默认不拦截（向后兼容），退出码 0",
        "test_file": "tests/test-agent-enforcement.sh",
        "test_name": "[S-agent-enforce-05] missing enforcement config defaults to allow",
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
