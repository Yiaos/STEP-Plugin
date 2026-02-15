---
description: "启动 STEP 协议（Stateful Task Execution Protocol）。自动检测项目状态，初始化或恢复到对应阶段。"
---

检查当前项目是否已初始化 STEP 协议（.step/ 目录是否存在）。

## 如果 .step/ 不存在（首次初始化）

1. 找到 STEP 插件根目录（`~/.config/opencode/tools/step/`）
2. 运行 `bash ~/.config/opencode/tools/step/scripts/step-init.sh`
3. 将 state.yaml 的 current_phase 设为 `phase-0-discovery`
4. **检查脚本输出**：如果输出包含 `[EXISTING PROJECT`，说明检测到已有代码库：
   - 先分析现有代码结构、框架、约定
   - 识别已建立的 patterns（命名、架构、测试策略）
   - 将现有项目上下文写入 `.step/baseline.md`, baseline将作为当前该项目的快照
   - 设置 `state.yaml` 的 `established_patterns`
   - 然后进入 Phase 0 讨论新需求
5. 如果是全新项目，直接告诉用户：进入 Phase 0 Discovery

## 如果 .step/ 已存在（恢复 Session）

1. 读取 `.step/state.yaml`
2. 读取 `.step/baseline.md`
3. 如果有当前任务，读取对应 task YAML
4. 根据 current_phase 进入对应阶段
5. 输出状态行：`📍 Phase X | Task: {slug} | Status: xxx | Next: xxx`
6. 从上次中断的位置继续

## 全阶段规则

加载 `step` skill 并严格遵守其中的规则。

核心规则速查：
- Phase 0 (Discovery): 开放式讨论，用户主导方向，LLM 提供分析。不逐个提问。
- Phase 1 (PRD): 分段展示 baseline.md 草稿，选择题确认细节。
- Phase 2 (Tech Design): 开放式讨论技术方案，LLM 提供对比分析。
- Phase 3 (Planning): 生成任务图和场景矩阵（BDD），用户审核确认。
- Phase 4 (Execution): TDD 循环（测试模型按 config.yaml 配置），gate 验证，每任务 Review+Commit。
- Phase 5 (Review): 独立审查（需求合规 > 代码质量）。

每次对话结束时**必须**更新 `.step/state.yaml`。
`next_action` 必须精确到文件名和具体动作，不允许写"继续开发"。

完整协议规范详见 `~/.config/opencode/tools/step/WORKFLOW.md`。
