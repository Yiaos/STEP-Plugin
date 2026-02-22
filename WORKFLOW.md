# STEP Workflow (Condensed)

> 从 "我有个想法" 到 "代码交付上线" 的全流程协议。
> 目标：状态可恢复、任务可追溯、质量可验证。

示例与补充文档：`docs/examples.md`、`docs/hooks.md`、`docs/design-notes.md`

## 命名规则

任务与变更统一使用**语义化 slug**（kebab-case）。

| 元素 | 格式 | 示例 |
|---|---|---|
| 变更目录 | `.step/changes/{change}/` | `changes/init/`, `changes/2026-02-20-add-dark-mode/` |
| 任务文件 | `.step/changes/{change}/tasks/{slug}.md` | `tasks/user-register-api.md` |
| 场景 ID | `S-{slug}-{seq}` | `S-user-register-api-01` |
| 归档目录 | `.step/archive/YYYY-MM-DD-{change}/` | `archive/2026-02-15-init/` |

初始开发使用 `init`，后续变更使用 `YYYY-MM-DD-{slug}`。

## Phase 概览

1. Phase 0 Discovery
2. Phase 1 PRD
3. Phase 2 Tech Design
4. Phase 3 Plan & Tasks
5. Phase 4 Execution
6. Phase 5 Review

Lite Mode：`L1 Quick Spec -> L2 Execution -> L3 Review`

## Phase 0 Discovery（开放式讨论）

- 用户主导探索，LLM 给分析，不做实现。
- 输出关键事实到 `findings.md`（可选）。
- **Findings 2-Action Rule（分级阈值）**：
  - Discovery/Lite-L1：每 2 个有效探索动作更新一次。
  - 规划阶段（Phase 1/2/3）：每 3 个有效探索动作更新一次。
  - 执行阶段（Phase 4/5、Lite-L2/L3）：每 4 个有效动作更新一次。

## Phase 1 PRD（选择题确认）

- 生成并确认 `baseline.md`。
- 输出 `spec.md`。
- baseline 确认后，后续变更必须走 `changes/`（不可直接覆写）。

## Phase 2 Tech Design（开放式讨论）

- 技术方案对比、取舍说明。
- 输出 `design.md` 与 ADR。

## Phase 3 Plan & Tasks（结构化确认）

- 任务拆分 + 依赖关系 + 场景矩阵。
- 场景是 BDD（Given/When/Then）。

### 场景矩阵（BDD）

- `test_type` 指定验证方式：unit / integration / e2e。
- unit / integration 为必须。
- e2e 在 Full 模式必须，Lite 模式按需。
- `scenario.status` 初始为 `not_run`。
- 运行 `scenario-check` 或 `gate` 后自动同步为 `pass` / `fail`。
- `task.status=done` 的前提：该 task 下所有场景必须 `pass`（不得存在 `not_run` / `fail`）。

任务 JSON 模板见：`templates/task.md`、`templates/lite-task.md`。

## Phase 4 Execution（TDD + Gate）

```
Step 1: 加载上下文并输出状态行
Step 2: 先写测试（RED）
Step 3: 再写实现
Step 4: 跑 gate（quick/lite/full）
Step 5: Review + Commit
Step 6: 更新 state + baseline.md 对应项 [ ] -> [x]
```

关键命令：

- `bash scripts/gate.sh quick {slug}`
- `bash scripts/gate.sh lite {slug}`
- `bash scripts/gate.sh full {slug} --all`
- `bash scripts/scenario-check.sh {slug} [change]`

## Phase 5 Review（两阶段）

1. Spec Compliance（阻断）
2. Code Quality（仅在第一阶段通过后）

Review 时必须展示新鲜证据（gate/scenario 输出）。

## Lite Mode

Lite Mode 适用于小范围任务（通常 <=3 文件、无架构变更）：

- **L1 Quick Spec**：一次确认。
- **L2 Execution**：TDD + gate。
- **L3 Review**：完整 Code Review。

Lite Batch（批量）支持一次确认多个小任务，再逐个执行。

## Agent 路由

按 `.step/config.json` 的 `routing/file_routing` 进行委派。

- Discovery/PRD -> step-pm
- Tech Design/Plan -> step-architect
- 测试编写 -> step-qa
- 后端执行 -> step-developer
- 前端执行 -> step-designer
- Review -> step-reviewer

Full 模式执行阶段可启用 dispatch 强约束；可通过 `enforcement.bypass_tools` 白名单豁免。

## Hook 与硬约束

- SessionStart：注入协议上下文。
- PreToolUse：phase/action/dispatch 校验。
- Stop：会话结束一致性检查。

说明见 `docs/hooks.md`。

## Gate 失败处理

- 先分析根因，再修复。
- 失败记录中 `next_action` 与 `failed_action` 必须不同。
- 最多自动修复 3 轮，超过则阻塞并请求人工介入。

## Worktree 自动流程

开启 `worktree.enabled=true` 后：

1. `create {change}` 创建工作树。
2. 开发提交完成后询问是否合并。
3. `finalize {change}` 合并、冲突处理、归档、清理。

## 归档

### 归档触发方式

- 完成后提示归档
- 用户自然语言（"归档"）
- 命令：`/archive` 或 `/archive {change-name}`

归档脚本：`step-archive.sh`

归档前置条件：**变更下所有 tasks 的 status 都为 done**，并满足场景状态闭环。

归档建议顺序：Review 通过后先提交，再提示是否归档；归档仅影响 `.step/changes/` 审计目录，不改变已提交代码。

## 自主操作规则

### 不需要用户确认

- git add / commit / push（非 force）
- 文件修改（方向已明确）
- 运行 test/lint/build/gate
- 创建目录

### 需要用户确认

- baseline 首版确认
- 方案分歧下的路线选择
- 需求变更（新建 change）
- `git push --force` / rebase 等高风险操作
- 不可逆操作

## 保证与限制

### 硬保证

- gate/scenario 脚本执行结果可复验。
- Hook 自动注入与校验。
- 结构化模板固定。

### 软保证

- 阶段顺序、TDD 顺序依赖模型遵守。
- baseline 契约无文件锁保护。

### 不能保证

- 会话内模型切换。
- 文件级写保护。

## Post-MVP 统一流程

- 新功能：新建 `changes/YYYY-MM-DD-{slug}/`
- Hotfix：`changes/YYYY-MM-DD-{slug}-hotfix/`
- 约束变更：先做影响分析再迁移

所有变更统一走：spec -> design -> tasks -> execution -> review -> commit -> archive(optional)。

## 附：状态恢复输出

恢复会话时输出：

`📍 Phase X | Change: {name} | Task: {slug} | Status: xxx | Next: xxx`

并从 `next_action` 继续。
