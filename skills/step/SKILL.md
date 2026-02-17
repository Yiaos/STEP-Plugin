---
name: step
description: "STEP Protocol — Stateful Task Execution Protocol. 全生命周期开发协议，通过状态机、质量门禁和 Session 恢复保证 AI 编码代理的交付质量。"
hooks:
  PreToolUse:
    - matcher: "Write|Edit|Bash"
      hooks:
        - type: command
          command: "cat .step/state.json 2>/dev/null | head -25 || true"
  PostToolUse:
    - matcher: "Write|Edit"
      hooks:
        - type: command
          command: "echo '[STEP] 文件已修改。如有阶段变化或重大决策，更新 .step/state.json 的 progress_log 和 key_decisions。'"
  Stop:
    - hooks:
        - type: command
          command: "bash scripts/step-stop-check.sh 2>/dev/null || echo '[STEP] 对话即将结束。必须更新 state.json: last_updated, progress_log（新条目插入列表最前，倒序）, next_action（精确到文件名和动作）。'"
---

# STEP Protocol — Core Rules

> Stateful Task Execution Protocol. 完整规范见 `WORKFLOW.md`（STEP 插件根目录）。

## 命名规则

任务使用**语义化 slug** 命名（参考 OpenSpec 理念）：

| 元素 | 格式 | 示例 |
|------|------|------|
| 变更目录 | `.step/changes/{change}/` | `changes/init/`, `changes/2026-02-20-add-dark-mode/` |
| 变更 findings | `.step/changes/{change}/findings.md` | `changes/init/findings.md`（可选） |
| 变更 spec | `.step/changes/{change}/spec.md` | `changes/init/spec.md` |
| 变更 design | `.step/changes/{change}/design.md` | `changes/init/design.md` |
| 任务文件 | `.step/changes/{change}/tasks/{slug}.md` | `changes/init/tasks/user-register-api.md` |
| 场景 ID | `S-{slug}-{seq}` | `S-user-register-api-01` |
| 归档 | `.step/archive/YYYY-MM-DD-{change}/` | `archive/2026-02-15-init/` |

**命名规则**: 初始开发用 `init`，后续变更用 `YYYY-MM-DD-{slug}`。任务 slug 为 kebab-case。Full/Lite 通过 task Markdown 内 JSON 代码块的 `mode` 字段区分。

## Phase 规则

### Phase 0: Discovery（开放式讨论）
- **用户主导**，LLM 是对话伙伴，不逐个提问
- 不做技术决策，不写代码
- 探索过程中发现关键事实/约束 → 写入 `.step/changes/{change}/findings.md`（可选）
- 重大发现应提炼为 ADR 写入 `decisions.md`
- 目标方向明确 + 边界清晰 + 用户确认 → 进入 Phase 1

### Phase 1: PRD（选择题确认）
- LLM 起草 `baseline.md` → 分段展示 → 选择题逐项确认
- 确认后写入 `.step/baseline.md` + `.step/changes/{change}/spec.md`
- 修改已确认的 baseline 必须通过新建变更（`.step/changes/YYYY-MM-DD-{slug}/`）

### Phase 2: Tech Design（开放式讨论）
- LLM 提供全面技术方案对比（优劣势、适用场景、推荐理由）
- 用户开放讨论，可追问细节、提出新方案
- 整体确定后，细节用选择题快速确认
- 技术调研中的中间发现 → 追加到 `.step/changes/{change}/findings.md`（可选）
- 输出: `.step/changes/{change}/design.md` + `.step/decisions.md`（ADR）

### Phase 3: Plan & Tasks（结构化确认）
- 生成任务图 + 依赖关系 + BDD 场景矩阵
- 每个任务 Markdown(JSON 代码块) 含: happy_path / edge_cases / error_handling 场景
- 场景 ID 格式: `S-{slug}-{seq}` (如 `S-user-register-api-01`)
- 每个场景通过 `test_type` 指定验证方式（unit / integration / e2e），**三种类型都是必须的**
- 用户审核确认后写入 `.step/changes/{change}/tasks/`

### Phase 4: Execution（TDD + Gate）
```
Step 1: 加载上下文 → 输出状态行
Step 2: 写测试（按 routing.test_writing 派发 @step-qa） → 确认全部 FAIL (TDD RED)
Step 3: 写实现（按 file_routing 选 agent） → 每场景跑 gate lite
  若 config.worktree.enabled=true：先执行 ./scripts/step-worktree.sh create {change}

Step 4: Gate 验证 → 小改动可 `gate.sh quick {slug}`，常规 `gate.sh lite {slug}`
Step 5: Review + Commit（每完成一个任务都执行）
  commit 后询问是否合并回主分支并归档
  用户确认后执行 ./scripts/step-worktree.sh finalize {change}
Step 6: 更新 state.json + baseline.md 对应项 [ ] → [x] → 进入下一任务
```

### Phase 5: Review（独立验证）
每完成一个任务触发，不等全部完成。

## Execution 硬规则

1. **测试先行**: 按 `config.json` 的 `routing.test_writing` 派发 @step-qa 写测试 → 确认 FAIL → 再写实现（QA 写测试 + Developer 写实现 = 天然对抗性）
2. **场景 ID 绑定**: 测试名必须包含 `[S-{slug}-xx]`
3. **Gate 必须带 slug**: `./scripts/gate.sh quick|lite|full {slug}`——必须指定 task-slug，确保 evidence 自动保存到 `.step/evidence/{slug}-gate.json`
4. **增量优先 + 全量兜底**: 日常执行默认增量 gate；Phase 5 Review 前、归档前必须执行一次 `./scripts/gate.sh full {slug} --all`
5. **场景 100% 覆盖**: `scenario-check.sh` 验证每个场景 ID 都有对应测试
6. **所有测试类型必须**: unit / integration / e2e 都是必须的，不可跳过
7. **修改前必须 Read**: 修改任何文件前必须先用 Read 工具查看当前内容，不得凭记忆编辑
8. **Baseline 完成跟踪**: 任务标记 done 时，同步更新 baseline.md 对应功能项 `[ ]` → `[x]`
9. **Evidence 必须保存**: gate 和 review 的证据必须保存到 `.step/evidence/`（gate 自动保存，review 需手动写入 `{slug}-review.md`）
10. **验证铁律**: <HARD-GATE>声称"测试通过"/"gate 通过"/"Review 通过"前，必须在本条消息中展示实际运行输出。没有新鲜证据的通过声明等于撒谎。</HARD-GATE>
11. **Gate 安全约束**: gate 命令执行前必须通过危险命令黑名单校验（`gate.dangerous_executables`）

## Gate 失败处理

```
Gate 失败 → 强模型(Opus/Codex xhigh)分析根因
  → root_cause + category + fix_strategy(可能多个)
  → 如有多种修复策略 → 展示选项给用户选择
  → 用户选择后执行修复 → 重跑 gate
  → 最多自动修复 3 轮
  → 仍失败 → status: blocked + 请求人工介入
```

**禁止盲修**：每轮修复前必须先做失败分析。

## Review 两阶段

Review 分两轮执行，第一轮不通过则不进入第二轮：

```
第一轮: Spec Compliance（需求合规 — 阻断）
  □ baseline.md 约束未违反
  □ MVP Scope 范围内
  □ User Story / AC 全部满足
  □ BDD 场景 100% 覆盖
  □ decisions.md ADR 一致
  □ 展示 gate + scenario-check 最新输出作为证据
  → 不通过 → REQUEST_CHANGES，不进入第二轮

第二轮: Code Quality（代码质量 — 仅在第一轮通过后）
  □ SOLID
  □ Security（XSS/注入/SSRF/AuthZ）
  □ 错误处理 / 性能 / 边界条件
```

严重程度: P0(需求不合规/安全/数据丢失) > P1(场景缺失/逻辑错误) > P2(代码异味) > P3(风格)

## Polish 检查点（Full mode 限定）

Gate 通过后、Review 前，由 @step-designer 执行打磨检查：
- loading 状态和骨架屏
- 错误提示友好性（用户能理解并行动）
- 空状态处理（首次使用引导）
- 过渡动画和视觉反馈
- 跨设备/响应式验证

Lite mode 跳过此检查点。

## 防漂移机制

- baseline.md 确认后不可直接修改 → 必须通过新建变更（changes/）
- 不可引入未经 ADR 记录的架构决策
- Post-MVP: 需求变更 → 新建功能变更，Bug → Hotfix，约束变更 → 高影响变更

## 保证与限制

### 硬保证（技术层面强制）
1. **gate.sh / scenario-check.sh** — 脚本执行结果是确定性的，跑了就准
2. **Subagent 模型绑定** — `agents/*.md` frontmatter 默认模型 + oh-my-opencode preset 覆盖，subagent 启动时模型确定
3. **SessionStart Hook 注入** — 有 `.step/` 目录就一定注入状态到上下文
4. **文件模板结构** — step-init.sh 创建的文件结构是确定性的

### 软保证（prompt 层面，依赖 LLM 遵守）
1. Phase 流转顺序 — LLM 可能跳过阶段
2. TDD 先测试后实现 — LLM 可能先写实现
3. 每次都跑 gate — LLM 可能跳过 gate 直接标 done
4. baseline 确认后不直接改 — 文件系统无写保护
5. 从 next_action 恢复 — LLM 可能不遵守

### 不能保证（需要外部机制）
1. 主会话中途切模型 — opencode 启动时选定模型，session 内不可变
2. 文件写保护 — baseline 确认是契约不是文件锁

### 提高遵守率的设计
- Hook 自动注入规则（不依赖用户记得提醒）
- 角色切换（不同 Phase 用不同 agent，每个 agent 有针对性约束）
- gate.sh 是真实可执行脚本（不是 checklist）
- scenario-check.sh 用 grep 硬匹配（不是 LLM 判断）

## 注意力管理

当 PreToolUse hook 注入 state.json 内容时（你会看到以 `⚡` 开头的规则行）：

1. **检查 progress_log** — 如果距上次更新已完成新的有意义工作，将新条目插入列表最前（倒序，最新在前）
2. **检查 key_decisions** — 如果做了新的技术/架构决策，将新条目插入列表最前（倒序，最新在前；含 decision + reason + phase + date）
3. **检查 next_action** — 如果当前工作已偏离上次记录的 next_action，更新它
PostToolUse 提醒不可忽略：每次 Write/Edit 后评估是否触发了状态变化。

## Session 管理

### 对话结束时必须做
1. 更新 `state.json`: last_updated, progress_log（新条目插入列表最前，倒序）, next_action
2. `next_action` 精确到文件名和具体动作
3. **禁止写** "继续开发" / "后续处理"
4. 如有重大决策，插入 `key_decisions` 列表最前（倒序；含 decision, reason, phase, date）

### 恢复 Session 时
1. 读 state.json → 读当前 change spec → 读当前 task → 读 baseline
2. 输出: `📍 Phase X | Change: {name} | Task: {slug} | Status: xxx | Next: xxx`
3. 从 next_action 继续

## Agent 路由（参考 .step/config.json）

编排器按 `config.json` 的 `routing` 表选择 agent，Phase 4 按 `file_routing` 的 patterns 分流：

| 阶段 | Agent | 路由依据 |
|------|-------|---------|
| Phase 0 Discovery | @step-pm | routing.discovery |
| Phase 1 PRD | @step-pm | routing.prd |
| Lite L1 Quick Spec | @step-pm | routing.lite_spec |
| Phase 2 Tech Design | @step-architect | routing.tech_design |
| Phase 3 Plan | @step-architect | routing.planning |
| Phase 3 场景补充 | @step-qa | routing.scenario |
| Phase 4 测试编写 | @step-qa | routing.test_writing |
| Phase 4 执行（后端） | @step-developer | file_routing.backend |
| Phase 4 执行（前端） | @step-designer | file_routing.frontend |
| Phase 5 Review | @step-reviewer | routing.review |
| Deploy（可选） | @step-deployer | routing.deploy |

Agent 默认模型在 `agents/*.md` frontmatter 中定义，可通过 oh-my-opencode preset 覆盖。

## 角色与 Agent 映射

STEP 定义 7 个角色，通过 `agents/*.md` 实现 subagent 模型绑定：

| 角色 | Agent | 默认模型 | 适用阶段 |
|------|-------|---------|---------|
| PM（产品经理） | @step-pm | claude-opus | Phase 0, 1 |
| Architect（架构师） | @step-architect | claude-opus | Phase 2, 3 |
| QA（质量工程师） | @step-qa | claude-opus | Phase 3 场景补充, Phase 4 Gate 分析, Phase 5 Review |
| Developer（开发者） | @step-developer | codex | Phase 4（后端） |
| Designer（UX 设计师） | @step-designer | gemini | Phase 2 UI 设计, Phase 4（前端） |
| Reviewer（代码审查） | @step-reviewer | codex | Phase 5 Review, Lite L3 |
| Deployer（部署策略） | @step-deployer | claude-opus | Review 通过后（可选） |

**制衡原则**: PM 定义"做什么"、Architect 定义"怎么做"、QA 定义"怎么破坏它"、Developer/Designer 只做被定义的事、Deployer 建议"怎么上线"。

## 对话模式

| 模式 | 阶段 | 特征 |
|------|------|------|
| 开放式讨论 | Phase 0, 2 | 用户主导，LLM 回应分析 |
| 选择题确认 | Phase 1, 3 | LLM 提供结构化选项，逐项确认 |

## Post-MVP 流程

Post-MVP 变更**与初始开发结构统一**，每个变更都是 `.step/changes/` 下的一个独立文件夹：

- **新增功能**: 新建 `.step/changes/YYYY-MM-DD-{slug}/`（含 spec.md + design.md + tasks/）→ 走 Phase 1-4 → gate + review + commit → 更新 baseline → 归档
- **Hotfix**: 新建 `.step/changes/YYYY-MM-DD-{slug}-hotfix/`（含 spec.md + design.md + tasks/）→ TDD 修复 → gate full 回归 → review + commit → 归档
- **约束变更**: 高影响变更 → spec.md 中注明影响分析 → 创建迁移任务 → Phase 4 执行 → gate full
- **Baseline 整理**: 多轮变更后 baseline 臃肿时。流程：归档旧版到 archive/ → 合成干净快照 → 同时精简 state.json 和 decisions.md → 用户确认后写入。审计链通过归档文件保留

**命名规则**: 初始开发用 `init`，后续变更用 `YYYY-MM-DD-{slug}` 开头，便于按时间查找。

## 自主操作规则

**不需要确认，直接执行：**
- git add / commit / push（不含 force push）
- 文件 CRUD（方向已达成共识）
- 运行 test / lint / build / gate
- install.sh --force
- 创建目录

**需要确认：**
- baseline 首版确认（Phase 1 出口）
- 技术方案选择（多选项时）
- 需求变更（新建变更）
- git push --force / rebase
- 不可逆操作

## Lite Mode（快速通道）

小型任务（≤ 3 文件、无架构变更、有已有 baseline）使用 3 阶段快速流程：

```
L1 Quick Spec → L2 Execution → L3 Review
(一次确认)      (TDD+gate lite)  (完整 Code Review)
```

### 触发
- 自动：短输入 + 范围关键词(fix/修复/加个/改下) + 无架构词 + 有 baseline
- 显式：`/step quick` / `lite` / `full`

Quick 模式由模型语义判断是否适用，不使用文件数/关键词硬约束；
若发现风险上升，必须升级到 lite/full，并记录 `escalation_reason`。

### L1: Quick Spec（派发 @step-pm，routing.lite_spec）
- 编排器派发 @step-pm 起草 lite task spec → 用户确认 → 写入 `.step/changes/{change}/tasks/{slug}.md`
- 批量任务: 一次展示多个 lite task → 一次确认 → 逐个执行
- 不分段确认、不修改 baseline 需求（允许完成标记 [ ] → [x]）、不做 ADR

### L2 + L3: 自主执行（L1 确认后不再打断用户）
- ✅ TDD 必须（测试先行）
- ✅ BDD 场景 100% 覆盖必须
- ✅ 场景 ID: `[S-{slug}-xx]`
- Gate: `gate.sh quick {slug}`（小改动）或 `gate.sh lite {slug}`（常规增量）
- e2e 按需
- Gate lite 通过 → 先执行 `gate.sh full {slug} --all` → **完整 Code Review**（需求合规 > 代码质量）
- Review 通过 → Commit → 更新 state.json + baseline.md
- **Lite 精简的是规划阶段，不是质量保证阶段**

### 完成后：Check + 迭代
- Commit 后提示用户 check 结果 + 询问是否归档
- 用户说"没问题" → 归档或保留
- **用户提出修改意见 → 不新建 task，在当前 task 上继续迭代**（status 回退 in_progress → 修改 → gate → review → commit → 再次 check）

### 升级规则
执行中发现复杂度超预期（影响 > 3 文件 / 需要新架构决策）→ **必须升级到 Full Mode**

## 归档

完成的变更（Full 和 Lite 均可）通过以下方式归档到 `.step/archive/YYYY-MM-DD-{change}/`：

**触发方式：**
1. **完成后提示** — 当前变更下所有任务 done 时，LLM 主动提示用户是否归档
2. **自然语言** — 用户说 "归档" 或 "归档 {change-name}"
3. **命令** — `/archive`、`/archive {change-name}`

**归档脚本**: `./scripts/step-archive.sh [change-name|--all]`

**规则**: 仅变更下所有任务都为 status: done 才可归档，归档不是删除（仍可搜索历史）。

## Worktree 模式（可选）

在 `.step/config.json` 里设置：

```json
{
  "worktree": {
    "enabled": true,
    "branch_prefix": "change/"
  }
}
```

启用后流程：
1. 变更开始时自动创建 worktree（create）
2. commit 完成后询问是否合并回主分支并归档
3. 用户确认后 finalize：合并 → 冲突交由大模型解决（保留双方有效改动）→ 归档 → 清理 worktree
   - 必须生成 `.step/conflict-report.md`
   - 必须向用户说明：冲突文件、每个文件的解决策略和原因、gate/scenario 验证结果

## 诊断命令

- 使用 `/step/status` 查看当前 phase、任务完成度、gate evidence 和阻塞项。
