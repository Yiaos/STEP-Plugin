---
name: step
description: "STEP Protocol — Stateful Task Execution Protocol. 全生命周期开发协议，通过状态机、质量门禁和 Session 恢复保证 AI 编码代理的交付质量。"
hooks:
  PreToolUse:
    - matcher: "Write|Edit|Bash"
      hooks:
        - type: command
          command: "cat .step/state.yaml 2>/dev/null | head -25 || true"
  PostToolUse:
    - matcher: "Write|Edit"
      hooks:
        - type: command
          command: "echo '[STEP] 文件已修改。如有阶段变化或重大决策，更新 .step/state.yaml 的 progress_log 和 key_decisions。'"
  Stop:
    - hooks:
        - type: command
          command: "bash scripts/step-stop-check.sh 2>/dev/null || echo '[STEP] 对话即将结束。必须更新 state.yaml: last_updated, progress_log（追加本次摘要）, next_action（精确到文件名和动作）。'"
---

# STEP Protocol — Core Rules

> Stateful Task Execution Protocol. 完整规范见 `WORKFLOW.md`（STEP 插件根目录）。

## 命名规则

任务使用**语义化 slug** 命名（参考 OpenSpec 理念）：

| 元素 | 格式 | 示例 |
|------|------|------|
| 任务文件 | `.step/tasks/{slug}.yaml` | `user-register-api.yaml` |
| 场景 ID | `S-{slug}-{seq}` | `S-user-register-api-01` |
| 归档文件 | `.step/archive/YYYY-MM-DD-{slug}.yaml` | `2026-02-15-user-register-api.yaml` |
| Hotfix | `YYYY-MM-DD-{slug}-hotfix-{seq}.yaml` | `2026-02-15-user-register-api-hotfix-001.yaml` |

**Slug 规则**: kebab-case、描述核心内容、不用序号前缀。Full/Lite 通过 YAML `mode` 字段区分。

## Phase 规则

### Phase 0: Discovery（开放式讨论）
- **用户主导**，LLM 是对话伙伴，不逐个提问
- 不做技术决策，不写代码
- 目标方向明确 + 边界清晰 + 用户确认 → 进入 Phase 1

### Phase 1: PRD（选择题确认）
- LLM 起草 `baseline.md` → 分段展示 → 选择题逐项确认
- 确认后写入 `.step/baseline.md`，标记冻结
- 修改冻结内容必须走 Change Request

### Phase 2: Tech Design（开放式讨论）
- LLM 提供全面技术方案对比（优劣势、适用场景、推荐理由）
- 用户开放讨论，可追问细节、提出新方案
- 整体确定后，细节用选择题快速确认
- 输出: `.step/tech-comparison.md` + `.step/decisions.md`

### Phase 3: Plan & Tasks（结构化确认）
- 生成任务图 + 依赖关系 + BDD 场景矩阵
- 每个任务 YAML 含: happy_path / edge_cases / error_handling 场景
- 场景 ID 格式: `S-{slug}-{seq}` (如 `S-user-register-api-01`)
- 每个场景通过 `test_type` 指定验证方式（unit / integration / e2e），**三种类型都是必须的**
- 用户审核确认后写入 `.step/tasks/`

### Phase 4: Execution（TDD + Gate）
```
Step 1: 加载上下文 → 输出状态行
Step 2: 写测试（按 config.yaml test_writing 模型） → 确认全部 FAIL (TDD RED)
Step 3: 写实现（按模型路由） → 每场景跑 gate quick
  ⚡ 每 2 次工具调用后，检查 progress_log / key_decisions 是否需要进度更新
Step 4: Gate 验证 → gate.sh standard {slug}
Step 5: Review + Commit（每完成一个任务都执行）
Step 6: 更新 state.yaml + baseline.md 对应项 [ ] → [x] → 进入下一任务
```

### Phase 5: Review（独立验证）
每完成一个任务触发，不等全部完成。

## Execution 硬规则

1. **测试先行**: 按 `config.yaml` 中 `test_writing.model` 指定的模型写测试 → 确认 FAIL → 再写实现（建议测试与实现用不同模型以形成对抗性）
2. **场景 ID 绑定**: 测试名必须包含 `[S-{slug}-xx]`
3. **Gate 必过**: `./scripts/gate.sh standard {slug}` 通过才能标 done
4. **场景 100% 覆盖**: `scenario-check.sh` 验证每个场景 ID 都有对应测试
5. **所有测试类型必须**: unit / integration / e2e 都是必须的，不可跳过
6. **修改前必须 Read**: 修改任何文件前必须先用 Read 工具查看当前内容，不得凭记忆编辑
7. **Baseline 完成跟踪**: 任务标记 done 时，同步更新 baseline.md 对应功能项 `[ ]` → `[x]`

## Gate 失败处理

```
Gate 失败 → 强模型(Opus/Codex xhigh)分析根因
  → root_cause + category + fix_strategy
  → 按分类修复 → 重跑 gate
  → 最多自动修复 3 轮
  → 仍失败 → status: blocked + 请求人工介入
```

**禁止盲修**：每轮修复前必须先做失败分析。

## Review 优先级

```
第一优先级: 需求合规（P0 阻断）
  □ baseline.md 约束未违反
  □ MVP Scope 范围内
  □ User Story / AC 全部满足
  □ BDD 场景 100% 覆盖
  □ decisions.md ADR 一致

第二优先级: 代码质量（参考 code-review-expert）
  □ SOLID
  □ Security（XSS/注入/SSRF/AuthZ）
  □ 错误处理 / 性能 / 边界条件
```

严重程度: P0(需求不合规/安全/数据丢失) > P1(场景缺失/逻辑错误) > P2(代码异味) > P3(风格)

## 防漂移机制

- baseline.md 冻结后不可直接修改 → 走 Change Request
- 不可引入未经 ADR 记录的架构决策
- Post-MVP: 需求变更 → CR，Bug → Hotfix，约束变更 → 高影响 CR

## 保证与限制

### 硬保证（技术层面强制）
1. **gate.sh / scenario-check.sh** — 脚本执行结果是确定性的，跑了就准
2. **Subagent 模型绑定** — 通过 `agents/*.md` 定义 + `oh-my-opencode` 配置，subagent 启动时模型确定
3. **SessionStart Hook 注入** — 有 `.step/` 目录就一定注入状态到上下文
4. **文件模板结构** — step-init.sh 创建的文件结构是确定性的

### 软保证（prompt 层面，依赖 LLM 遵守）
1. Phase 流转顺序 — LLM 可能跳过阶段
2. TDD 先测试后实现 — LLM 可能先写实现
3. 每次都跑 gate — LLM 可能跳过 gate 直接标 done
4. baseline 冻结不直接改 — 文件系统无写保护
5. 从 next_action 恢复 — LLM 可能不遵守

### 不能保证（需要外部机制）
1. 主会话中途切模型 — opencode 启动时选定模型，session 内不可变
2. 文件写保护 — baseline 冻结是契约不是文件锁

### 提高遵守率的设计
- Hook 自动注入规则（不依赖用户记得提醒）
- 角色切换（不同 Phase 用不同 agent，每个 agent 有针对性约束）
- gate.sh 是真实可执行脚本（不是 checklist）
- scenario-check.sh 用 grep 硬匹配（不是 LLM 判断）

## 注意力管理

当 PreToolUse hook 注入 state.yaml 内容时（你会看到以 `⚡` 开头的规则行）：

1. **检查 progress_log** — 如果距上次更新已完成新的有意义工作，立即追加条目
2. **检查 key_decisions** — 如果做了新的技术/架构决策，立即记录（decision + reason + phase + date）
3. **检查 next_action** — 如果当前工作已偏离上次记录的 next_action，更新它
4. **每 2 次工具调用** — 自省一次是否需要更新上述字段

PostToolUse 提醒不可忽略：每次 Write/Edit 后评估是否触发了状态变化。

## Session 管理

### 对话结束时必须做
1. 更新 `state.yaml`: last_updated, progress_log（追加本次摘要）, next_action
2. `next_action` 精确到文件名和具体动作
3. **禁止写** "继续开发" / "后续处理"
4. 如有重大决策，追加到 `key_decisions`（含 decision, reason, phase, date）

### 恢复 Session 时
1. 读 state.yaml → 读当前 task → 读 baseline
2. 输出: `📍 Phase X | Task: {slug} | Status: xxx | Next: xxx`
3. 从 next_action 继续

## 模型路由（参考 .step/config.yaml）

| 阶段 | 模型 |
|------|------|
| Phase 0-3 规划 | claude-opus |
| 测试编写 | 按 config.yaml 配置（默认 codex） |
| 前端实现 | gemini |
| 后端实现 | codex |
| 复杂逻辑 | claude-opus |
| Review | claude-opus 或 codex |

## 角色与 Agent 映射

STEP 定义 4 个角色，通过 `agents/*.md` 实现 subagent 模型绑定：

| 角色 | Agent 文件 | 模型 | 适用阶段 |
|------|-----------|------|---------| 
| PM（产品经理） | `agents/pm.md` | claude-opus | Phase 0, 1 |
| Architect（架构师） | `agents/architect.md` | claude-opus | Phase 2, 3 |
| QA（质量工程师） | `agents/qa.md` | claude-sonnet-thinking | Phase 3 场景补充, Phase 4 Gate 分析, Phase 5 Review |
| Developer（开发者） | `agents/developer.md` | codex | Phase 4 |

**制衡原则**: PM 定义"做什么"、Architect 定义"怎么做"、QA 定义"怎么破坏它"、Developer 只做被定义的事。

## 对话模式

| 模式 | 阶段 | 特征 |
|------|------|------|
| 开放式讨论 | Phase 0, 2 | 用户主导，LLM 回应分析 |
| 选择题确认 | Phase 1, 3 | LLM 提供结构化选项，逐项确认 |

## Post-MVP 流程

Post-MVP 变更**同样遵循 STEP 协议**，所有过程记录在 `.step/` 下：

- **Change Request**: 需求变更 → `.step/change-requests/YYYY-MM-DD-CR-{slug}.yaml` → 用户审批 → 更新 baseline → 创建新 task YAML（含场景矩阵） → Phase 4 执行 → gate + review + commit
- **Hotfix**: Bug → 定位场景 → `.step/tasks/YYYY-MM-DD-{slug}-hotfix-{seq}.yaml` → TDD 修复 → gate full 回归 → review + commit → 更新 state.yaml
- **约束变更**: 高影响 CR → 影响分析 → 创建迁移任务 → Phase 4 执行 → gate full

**命名规则**: CR 和 Hotfix 文件名以日期开头（`YYYY-MM-DD-`），便于按时间查找。

## 自主操作规则

**不需要确认，直接执行：**
- git add / commit / push（不含 force push）
- 文件 CRUD（方向已达成共识）
- 运行 test / lint / build / gate
- install.sh --force
- 创建目录

**需要确认：**
- baseline 冻结（Phase 1 出口）
- 技术方案选择（多选项时）
- 需求变更（CR）
- git push --force / rebase
- 不可逆操作

## Lite Mode（快速通道）

小型任务（≤ 3 文件、无架构变更、有已有 baseline）使用 3 阶段快速流程：

```
L1 Quick Spec → L2 Execution → L3 Review
(一次确认)      (TDD+gate standard)  (完整 Code Review)
```

### 触发
- 自动：短输入 + 范围关键词(fix/修复/加个/改下) + 无架构词 + 有 baseline
- 显式：`/step lite` 或 `/step full`

### L1: Quick Spec
- 一次性输出 lite task spec → 用户确认 → 写入 `.step/tasks/{slug}.yaml`
- 批量任务: 一次展示多个 lite task → 一次确认 → 逐个执行
- 不分段确认、不冻结 baseline、不做 ADR

### L2: Execution
- ✅ TDD 必须（测试先行）
- ✅ BDD 场景 100% 覆盖必须
- ✅ 场景 ID: `[S-{slug}-xx]`
- Gate: `gate.sh standard {slug}`
- e2e 按需

### L3: Review（与 Full Mode 相同）
- Gate standard 通过 → **完整 Code Review**（需求合规 > 代码质量）
- Review 通过 → Commit → 更新 state.yaml + baseline.md
- **Lite 精简的是规划阶段，不是质量保证阶段**

### 升级规则
执行中发现复杂度超预期（影响 > 3 文件 / 需要新架构决策）→ **必须升级到 Full Mode**

## 归档

完成的任务（Full 和 Lite 均可）通过以下方式归档到 `.step/archive/YYYY-MM-DD-{slug}.yaml`：

**触发方式：**
1. **完成后提示** — 所有任务 done 时，LLM 主动提示用户是否归档
2. **自然语言** — 用户说 "归档 {slug}" 或 "归档所有任务"
3. **命令** — `/archive`、`/archive all`、`/archive {slug}`

**归档脚本**: `./scripts/step-archive.sh [slug|--all]`

**规则**: 仅 status: done 的任务可归档，归档不是删除（仍可搜索历史）。
