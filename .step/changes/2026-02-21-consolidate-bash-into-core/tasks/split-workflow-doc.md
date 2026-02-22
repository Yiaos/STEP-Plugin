# Split WORKFLOW.md into protocol + docs

```json task
{
  "id": "split-workflow-doc",
  "title": "Split WORKFLOW.md into protocol + docs",
  "mode": "full",
  "status": "done",
  "depends_on": [
    "unify-e2e-rule"
  ],
  "goal": "WORKFLOW.md 从 1507 行拆分为：WORKFLOW.md (~700 行纯协议规范) + docs/examples.md + docs/hooks.md + docs/design-notes.md。",
  "non_goal": [
    "不修改协议规则本身",
    "不修改 SKILL.md（SKILL.md 是独立的注入内容）"
  ],
  "done_when": [
    "WORKFLOW.md 行数 < 800",
    "docs/examples.md 存在且包含 Lite 完整流程和对话示例",
    "docs/hooks.md 存在且包含 Hook/Command 实现细节和 AGENTS.md 模板",
    "docs/design-notes.md 存在且包含 9 个反馈对应记录",
    "WORKFLOW.md 中 Lite Mode 段落 < 40 行并指向 docs/examples.md"
  ],
  "scenarios": {
    "happy_path": [
      {
        "id": "S-split-workflow-doc-01",
        "given": "拆分后的 WORKFLOW.md",
        "when": "检查内容",
        "then": "包含 Phase 0-5 定义、流转规则、保证与限制、自主操作规则、Post-MVP 流程、场景覆盖机制",
        "test_file": "tests/test-workflow-split.sh",
        "test_name": "[S-split-workflow-doc-01] WORKFLOW.md retains core protocol",
        "test_type": "integration",
        "status": "pass"
      },
      {
        "id": "S-split-workflow-doc-02",
        "given": "拆分后的 docs/ 目录",
        "when": "检查三个文件",
        "then": "examples.md + hooks.md + design-notes.md 均存在且非空",
        "test_file": "tests/test-workflow-split.sh",
        "test_name": "[S-split-workflow-doc-02] docs files exist and non-empty",
        "test_type": "unit",
        "status": "pass"
      }
    ],
    "edge_cases": [
      {
        "id": "S-split-workflow-doc-03",
        "given": "WORKFLOW.md 中引用了被移走的段落",
        "when": "检查内部链接",
        "then": "所有引用更新为指向 docs/ 下对应文件",
        "test_file": "tests/test-workflow-split.sh",
        "test_name": "[S-split-workflow-doc-03] cross-references updated",
        "test_type": "unit",
        "status": "pass"
      }
    ],
    "error_handling": [
      {
        "id": "S-split-workflow-doc-04",
        "given": "拆分后的文件",
        "when": "合并所有文件内容",
        "then": "无信息丢失（原 WORKFLOW.md 的所有段落都能在拆分后的文件中找到）",
        "test_file": "tests/test-workflow-split.sh",
        "test_name": "[S-split-workflow-doc-04] no content lost in split",
        "test_type": "integration",
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
