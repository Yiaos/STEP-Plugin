# STEP vs superpowers 详细对比

> 基于 STEP baseline v2 + superpowers v4.3.0（2026-02-16）对比。

## 1. 定位差异

**STEP**：全生命周期开发协议。6 阶段状态机 + 脚本级硬门禁 + 7 角色对抗 + 三层注意力 Hook + 全自动 Session 恢复。目标是可验证交付。

**superpowers**：工程纪律技能套件。用铁律式 prompt 语言约束 AI 行为，防止捷径与猜测。v4.3.0 新增 brainstorming 硬门禁 + subagent-driven-development 两阶段 review。目标是技术严谨。

一句话：STEP 是"全链路结构化协议 + 可执行保证"，superpowers 是"执行节点铁律纪律 + subagent 自动化"。

## 2. 覆盖范围

| 阶段 | STEP | superpowers |
|------|------|-------------|
| 需求发现 | ✅ Phase 0 Discovery + findings.md | ✅ brainstorming（HARD-GATE 强制） |
| 需求定义 | ✅ Phase 1 → baseline 确认 | ❌ |
| 技术设计 | ✅ Phase 2 → ADR + design.md | ⚠️ brainstorming 包含 design section |
| 任务规划 | ✅ Phase 3 → BDD 场景矩阵 | ✅ writing-plans（2-5 分钟粒度） |
| 执行编码 | ✅ Phase 4（TDD + gate 检查点） | ✅ subagent-driven-development / executing-plans |
| 测试 | ✅ QA 角色 + scenario-check.sh | ✅ TDD 铁律 |
| 代码审查 | ✅ Phase 5 两阶段 Review | ✅ 两阶段 review（spec → quality） |
| 调试 | ✅ Gate 失败分级处理 | ✅ systematic-debugging |
| 验证铁律 | ✅ HARD-GATE + gate.sh 真实执行 | ✅ verification-before-completion |
| Session 恢复 | ✅ SessionStart Hook 全自动 | ❌ |
| Post-MVP | ✅ 新增功能变更 / Hotfix / Baseline 整理 | ❌ |
| 注意力管理 | ✅ 三层 Hook | ⚠️ 1% 触发规则 |
| 并行 subagent | ❌（受限于平台） | ✅ subagent-driven-development |
| Git worktree 隔离 | ❌ | ✅ using-git-worktrees |

STEP 覆盖全链路；superpowers 聚焦执行节点纪律但通过 subagent 实现高度自动化。

## 3. 质量保证方式对比（脚本级 vs prompt 级）

| 机制 | STEP | superpowers |
|------|------|-------------|
| 门禁执行 | gate.sh 脚本（确定性结果） | prompt 铁律 + HARD-GATE 标签 |
| 场景覆盖 | scenario-check.sh 硬匹配 | 无 |
| TDD 保证 | QA 写测试 ≠ Developer 写实现（角色分离） | "无失败测试不得写生产代码"（铁律） |
| 审查保证 | 两阶段 Review（spec compliance → code quality） | 两阶段 review（spec → quality，通过 subagent） |
| 调试保证 | Gate 失败 → 根因分析 → 3 轮 → blocked | "禁止未定位根因就修复"（铁律） |
| 证据留存 | evidence/ + HARD-GATE 验证铁律 | verification-before-completion 铁律 |
| 防撒谎 | HARD-GATE + gate.sh 真实执行 | 铁律语言 + rationalization prevention 表 |

核心差异：STEP 双层保证（脚本 + prompt），superpowers 单层（prompt），但 superpowers 的 prompt 约束极端且系统化（rationalization prevention 表列出所有逃避借口）。

## 4. 工程严谨性逐项对比

| 纪律点 | STEP 机制 | superpowers 机制 |
|--------|----------|-----------------|
| 不跳过设计 | Phase 0→1→2 阶段流转 + agent routing | brainstorming HARD-GATE |
| 不跳过测试 | scenario-check.sh 硬匹配 + QA/Developer 角色分离 | TDD 铁律 + "删除并重来" |
| 不猜测错误原因 | Gate 失败 → 强模型根因分析 + QA "严禁猜测" | systematic-debugging 铁律 |
| 不空洞审查 | 两阶段 Review + "至少 3 个具体发现" | 两阶段 review（spec → quality） |
| 不跳步执行 | depends_on 依赖链 + gate 阻断 | executing-plans 检查点 |
| 不篡改需求 | baseline + 变更审计链 | 无对应机制 |
| 证据留存 | evidence/ + HARD-GATE 验证铁律 | verification-before-completion |
| 不撒谎 | HARD-GATE + gate.sh 真实执行 | rationalization prevention 表 |

## 5. Review 对比（STEP 已吸收两阶段模式）

STEP（v2 + 两阶段）：
- 第一轮 Spec Compliance：baseline 合规 + BDD 覆盖 + ADR 一致 + 测试可信度
- HARD-GATE：第一轮必须展示 gate + scenario-check 最新输出作为证据
- 第一轮不通过 → REQUEST_CHANGES，不进入第二轮
- 第二轮 Code Quality：SOLID + 安全 + 性能 + 边界条件
- 由 @step-reviewer 单 agent 分两步执行

superpowers（v4.3.0 subagent-driven-development）：
- 第一轮 Spec Compliance：由独立 spec-reviewer subagent 执行
- 第二轮 Code Quality：由独立 code-quality-reviewer subagent 执行
- 每轮由不同 subagent 执行（上下文隔离）
- 不通过 → implementer subagent 修复 → 重新 review

**差异**：superpowers 用独立 subagent 做 review（上下文隔离更强），STEP 用同一 agent 分两步（更高效但上下文可能交叉污染）。

## 6. TDD 对比

STEP：
- config.yaml routing.test_writing 指定 @step-qa 写测试
- Developer 角色写实现（不同 agent、可能不同模型）
- 每场景跑 gate quick（检查点），全部通过跑 gate standard
- scenario-check.sh 验证 BDD 场景 ID 100% 覆盖

superpowers：
- "无失败测试不得写生产代码"铁律
- 写了未覆盖代码则"全部删除并重来"
- subagent 自我 review + 外部 review 双重检查
- 无角色分离，无脚本验证

TDD 纪律一致。STEP 通过角色分离 + 脚本硬匹配实现；superpowers 通过铁律 + subagent review 实现。

## 7. 计划与执行对比

STEP：
- Phase 3 BDD 场景矩阵驱动任务拆分（每场景 = 一个检查点）
- Phase 4 每场景跑 gate quick，全部通过跑 gate standard
- depends_on 依赖链，Developer "严禁跳过或乱序"
- Gate 失败 3 轮 → blocked 阻断

superpowers：
- writing-plans 2-5 分钟粒度任务拆解（比 STEP 更细）
- 两种执行模式：subagent-driven（同 session）/ executing-plans（跨 session）
- subagent-driven: 每任务一个 subagent + 两阶段 review
- executing-plans: 3 任务一批 + 人工检查点

**差异**：superpowers 的任务粒度更细（2-5 分钟 vs STEP 的 BDD 场景级），且有 subagent 自动执行能力。STEP 的检查点是脚本级的，superpowers 是 subagent review 级的。

## 8. 互补性分析

**STEP 有而 superpowers 没有的**：
- 全生命周期 6 阶段（superpowers 没有 PRD、baseline、变更管理）
- 会话恢复状态机 + SessionStart Hook
- 可执行门禁脚本（gate.sh + scenario-check.sh）
- 需求基线 + 变更审计链（baseline.md + decisions.md + archive/）
- 角色分离与模型绑定（7 agent + config.yaml routing）
- Baseline 整理流程
- findings.md 探索发现持久化

**superpowers 有而 STEP 没有的**：
- subagent-driven-development（每任务独立 subagent，上下文隔离）
- git worktree 隔离（每变更独立工作空间）
- rationalization prevention 表（系统化列出所有逃避借口）
- 2-5 分钟粒度任务拆解（比 STEP 场景级更细）

**STEP 已吸收的**：
- ✅ 两阶段 Review（spec compliance → code quality）
- ✅ HARD-GATE 标签（关键门禁用 XML 标签强化信号）
- ✅ 验证铁律（claim 前必须展示新鲜证据）

## 9. superpowers 流程优势

### 9.1 subagent-driven-development

superpowers 的核心流程优势。每个任务由独立 subagent 执行：
- **上下文隔离**：任务间不互相污染
- **自动迭代**：review 不通过 → 同一 subagent 修复 → 重新 review
- **双重保证**：subagent 自我 review + 外部两阶段 review

STEP 受限于 opencode 的 subagent 能力，目前不可实现。记录为未来方向。

### 9.2 git worktree 隔离

每个变更在独立 worktree 中开发，零冲突风险。STEP 当前串行执行不需要，但并行变更支持时需要考虑。

### 9.3 rationalization prevention

superpowers 的 verification-before-completion 列出 12 种"逃避验证的借口"和对应的"现实"。这是 prompt 工程的极致——预先封堵所有 LLM 可能的逃避路径。STEP 的 HARD-GATE 标签是同方向的实践，但没有系统化列出逃避模式。

## 10. superpowers 缺少什么

1. 全生命周期流程（没有 PRD、baseline、变更管理）
2. 会话恢复与状态机（Session 断了要从头来）
3. 可执行门禁脚本（没有 gate.sh / scenario-check.sh）
4. 需求基线 + 变更审计链（没有 baseline.md / archive/）
5. 角色分离与对抗性验证（用 subagent 实现部分分离，但不如 7 角色系统化）
6. BDD 场景矩阵 + ID 硬匹配（没有 scenario-check.sh）
7. 结构化证据存档（没有 evidence/ 目录）
8. 注意力管理三层 Hook（只有 1% 触发规则 + SessionStart hook）
9. Baseline 整理流程（没有 Post-MVP 流程）
10. findings.md 探索发现持久化

## 11. 总结

superpowers v4.3.0 比旧版有了质的飞跃——brainstorming HARD-GATE + subagent-driven-development + verification-before-completion 三者组合使其从"纪律标签集"进化为"半自动化开发工作流"。

STEP 和 superpowers 的核心差异仍然是保证层级：STEP 双层（脚本 + prompt），superpowers 单层（prompt），但 superpowers 的 prompt 约束更极端更系统化。

STEP 已吸收 superpowers 的三个优势（两阶段 Review、HARD-GATE 标签、验证铁律）。superpowers 的 subagent-driven-development 仍是最大的流程优势，但受限于 STEP 的平台能力无法直接借鉴。
