---
description: "初始化或恢复 STEP 协议（Stateful Task Execution Protocol）。"
---

支持模式：
- `/step quick`：小改动快速路径（由模型判断是否适用，可中途升级）
- `/step lite`：轻量任务路径
- `/step full`：完整流程路径

说明：Quick 不使用文件数/关键词硬阈值，由模型按语义判断。

检查当前项目是否已初始化 STEP 协议（`.step/` 目录是否存在）。

## 如果 .step/ 不存在（首次初始化）

1. 设定插件根目录变量：`OPENCODE_PLUGIN_ROOT=${OPENCODE_PLUGIN_ROOT:-$HOME/.config/opencode/tools/step}`
2. 运行 `bash ${OPENCODE_PLUGIN_ROOT:-$HOME/.config/opencode/tools/step}/scripts/step-init.sh`
3. 将 state.json 的 `current_phase` 设为 `phase-0-discovery`
4. 若输出包含 `[EXISTING PROJECT`：
   - 分析现有代码结构、框架与约定
   - 识别 established patterns（命名、架构、测试策略）
   - 将上下文写入 `.step/baseline.md`
   - 设置 `state.json` 的 `established_patterns`
5. 若是全新项目，进入 Phase 0 Discovery

## 如果 .step/ 已存在（恢复 Session）

1. 读取 `.step/state.json`
2. 读取 `.step/baseline.md`
3. 如果有当前任务，读取对应 task Markdown(JSON 代码块)
4. 根据 `current_phase` 进入对应阶段
5. 输出状态行：`📍 Phase X | Change: {name} | Task: {slug} | Status: xxx | Next: xxx`
6. 从上次中断位置继续

## Worktree 自动模式（可选）

如果 `.step/config.json` 中：

```json
{
  "worktree": {
    "enabled": true
  }
}
```

则在变更开始阶段自动创建独立 worktree：

- 执行 `bash ${OPENCODE_PLUGIN_ROOT:-$HOME/.config/opencode/tools/step}/scripts/step-worktree.sh create {change-name}`
- 在该 worktree 内执行 Phase 4（TDD + gate + review + commit）
- commit 后询问是否“合并回创建时所在分支并归档”

## 可用性前置检查

进入 STEP 流程前，先执行：

`bash ${OPENCODE_PLUGIN_ROOT:-$HOME/.config/opencode/tools/step}/scripts/step-manager.sh doctor`

然后必须进入状态机执行态（示例）：

`bash ${OPENCODE_PLUGIN_ROOT:-$HOME/.config/opencode/tools/step}/scripts/step-manager.sh enter --mode full --change init`

- 若检查结果为 PASS：继续进入对应阶段
- 若检查结果为 FAIL：立即停止进入流程，先按脚本输出的修复命令完成修复（例如 `bash ${OPENCODE_PLUGIN_ROOT:-$HOME/.config/opencode/tools/step}/install.sh --force`）
- 若未 enter：PreToolUse 会先自动 enter（默认 full），再按当前 phase 校验 Write/Edit/Bash/Task；不会在 `idle` 直接放行实现命令

## 全阶段规则

加载 `step` skill 并严格遵守规则。

- Phase 0 (Discovery): 开放式讨论，用户主导方向
- Phase 1 (PRD): 分段展示 baseline 草稿，选择题确认
- Phase 2 (Tech Design): 开放式技术方案讨论
- Phase 3 (Planning): 任务图与 BDD 场景矩阵
- Phase 4 (Execution): TDD + gate + review + commit
- Phase 5 (Review): 独立审查（需求合规 > 代码质量）

每次对话结束必须更新 `.step/state.json`。`next_action` 必须精确到文件名和动作。
