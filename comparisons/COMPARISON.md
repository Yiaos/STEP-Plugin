# STEP vs. 同类工具对比分析

> 基于 STEP baseline v2（2026-02-16）重新对比。

---

## 一、各工具概览

| | STEP | BMAD-METHOD | OpenSpec | planning-with-files | superpowers |
|---|---|---|---|---|---|
| **定位** | 全生命周期开发协议 + opencode 插件 | AI 驱动的敏捷开发框架 | Spec 驱动开发 (SDD) | 文件驱动的计划管理 | 工程纪律技能套件 |
| **安装方式** | `bash install.sh` (opencode 插件) | `npx bmad-method install` (npm) | `npm install -g @fission-ai/openspec` | opencode skill (内置) | opencode skill (内置) |
| **支持平台** | opencode | Claude Code, Cursor, Windsurf 等 | 20+ AI 编码工具 | opencode | opencode |
| **核心哲学** | 状态机 + 硬门禁 + 角色对抗 + Session 恢复 | 多 Agent 协作 + Scale-Adaptive | 先规范后编码，流动迭代 | 文件系统作外部 RAM | 铁律纪律，禁止走捷径 |

---

## 二、生命周期覆盖对比

| 阶段 | STEP | BMAD | OpenSpec | planning-with-files | superpowers |
|------|------|------|---------|---------------------|-------------|
| 需求发现 | ✅ Phase 0 Discovery | ✅ product-brief | ⚠️ proposal.md (轻量) | ❌ | ✅ brainstorming |
| 需求定义/PRD | ✅ Phase 1 → baseline.md（用户确认） | ✅ create-prd | ✅ specs/ | ❌ | ❌ |
| 技术设计 | ✅ Phase 2 → ADR | ✅ create-architecture | ✅ design.md | ❌ | ❌ |
| 任务规划 | ✅ Phase 3 → BDD 场景矩阵 | ✅ epics/stories | ✅ tasks.md | ✅ task_plan.md | ✅ writing-plans |
| 执行编码 | ✅ Phase 4（TDD + gate 检查点） | ✅ dev-story | ✅ /opsx:apply | ✅ 持续同步 | ✅ executing-plans |
| 测试策略 | ✅ BDD + scenario-check.sh 硬匹配 | ⚠️ Quinn 内置 | ❌ | ❌ | ✅ TDD 铁律 |
| 质量门禁 | ✅ gate.sh（脚本级阻断） | ⚠️ code-review 流程 | ❌ | ❌ | ⚠️ prompt 级检查 |
| 代码审查 | ✅ Phase 5 Review（Reviewer agent） | ✅ code-review | ❌ | ❌ | ✅ code-review 铁律 |
| Session 恢复 | ✅ SessionStart Hook 全自动 | ❌ | ❌ | ✅ session-catchup.py 半自动 | ❌ |
| Post-MVP 变更 | ✅ 新增功能变更 / Hotfix / 约束变更 / Baseline 整理 | ✅ sprint 迭代 | ✅ archive + 新 change | ❌ | ❌ |
| 需求防漂移 | ✅ baseline 确认 + 变更审计链 | ⚠️ PRD 无确认 | ⚠️ proposal 无确认 | ❌ | ❌ |
| 注意力管理 | ✅ PreToolUse/PostToolUse/Stop 三层 Hook | ❌ | ❌ | ✅ 2-Action Rule + 钩子 | ⚠️ 1% 触发规则 |

**覆盖度**: STEP 12/12 | BMAD 8/12 | OpenSpec 5/12 | planning-with-files 3/12 | superpowers 5/12

---

## 三、角色/Agent 系统对比

| 维度 | STEP | BMAD | OpenSpec | planning-with-files | superpowers |
|------|------|------|---------|---------------------|-------------|
| 角色数量 | 7 | 12+ | 无 | 无 | 无 |
| 角色绑定方式 | agents/*.md + subagent 模型绑定 | prompt persona | — | — | — |
| 对抗性 | ✅ QA ≠ Developer，Reviewer 独立 | ⚠️ 角色间无对抗机制 | — | — | — |
| 多角色协作 | 顺序对抗（阶段切换） | Party Mode（同时讨论） | — | — | — |

STEP 以"少角色 + 硬绑定 + 对抗性"换取可靠性；BMAD 以"多角色 + 流程丰富"换取覆盖面。

---

## 四、执行保证机制对比

| 机制 | STEP | BMAD | OpenSpec | planning-with-files | superpowers |
|------|------|------|---------|---------------------|-------------|
| 可执行脚本门禁 | ✅ gate.sh + scenario-check.sh + step-stop-check.sh | ❌ | ❌ | ❌ | ❌ |
| Hook 自动注入 | ✅ SessionStart + PreToolUse + PostToolUse + Stop | ❌ | ❌ | ⚠️ pre/post 钩子 | ⚠️ 1% 触发 |
| Agent 模型绑定 | ✅ 不同角色→不同模型 | ❌ 同模型 persona | ❌ | ❌ | ❌ |
| BDD 场景 ID 硬匹配 | ✅ [S-xxx-xx] | ❌ | ❌ | ❌ | ❌ |
| 状态机 | ✅ state.json（Phase + Task + next_action） | ❌ | ❌ | ⚠️ task_plan.md 手动 | ❌ |
| Gate 失败分级 | ✅ 根因分析 → 3 轮上限 → blocked | ❌ | ❌ | ❌ | ⚠️ 铁律语言约束 |
| 需求基线确认 | ✅ baseline.md + 变更审计链 | ❌ | ❌ | ❌ | ❌ |
| 防遗忘 | ✅ 2-Action Rule + Pre-decision Read | ❌ | ❌ | ✅ 原创 2-Action Rule | ❌ |
| 防撒谎 | ✅ Agent 约束 + gate.sh 真实执行验证 | ❌ | ❌ | ❌ | ✅ 铁律语言 |

**保证层级**：STEP 有 4 个硬保证（gate.sh、scenario-check.sh、subagent 绑定、SessionStart Hook）+ prompt 级软保证。其余工具全部是 prompt 级。

---

## 五、适用场景推荐

| 场景 | 最佳选择 | 原因 |
|------|---------|------|
| 全新 MVP 产品 | STEP 或 BMAD | 全生命周期覆盖 |
| 已有代码库新功能 | STEP 或 OpenSpec | STEP 有项目检测；OpenSpec brownfield 友好 |
| 大型企业多人协作 | BMAD | Scale-Adaptive + 角色生态 |
| 快速原型 / 小功能 | OpenSpec | /opsx:ff 一键规划 |
| 复杂调研 / 长期重构 | planning-with-files | findings.md 持久化调研上下文 |
| 严肃生产代码质量 | STEP | 唯一有脚本级硬门禁 |
| Bug 修复 | STEP Lite 或 superpowers | STEP Lite 有 TDD + gate；superpowers 有 systematic-debugging |
| 跨 Session 长期开发 | STEP | 唯一有全自动 Session 恢复 |

---

## 六、核心差异总结

### STEP 独有能力
1. 可执行质量门禁（gate.sh + scenario-check.sh 是真实脚本）
2. BDD 场景矩阵 + ID 硬匹配覆盖率验证
3. 全自动 Session 恢复（SessionStart Hook）
4. 需求基线确认 + 变更审计链 + Baseline 整理流程
5. Agent 模型路由（7 角色绑定不同模型）
6. 三层注意力管理 Hook（PreToolUse / PostToolUse / Stop）
7. Gate 失败分级处理（根因分析 → 3 轮 → blocked）
8. 倒序 state.json（最新决策/进度在前，Session 恢复时首先看到）

### STEP 相对劣势
1. 平台绑定 opencode（BMAD 支持多平台，OpenSpec 支持 20+ 工具）
2. 角色数量少于 BMAD（7 vs 12+，不覆盖 UX 专家、DevOps 专家、Tech Writer）
3. 不支持并行开发多个功能（OpenSpec 的变更独立文件夹模式）
4. 无 Scale-Adaptive（BMAD 自动调整规划深度）
5. 社区生态（BMAD 35k stars；STEP 新项目）

---

## 七、可借鉴点分析

| 来源 | 特性 | 评估 |
|------|------|------|
| planning-with-files | findings.md 调研记录 | 有价值。decisions.md 的"替代方案"字段已部分覆盖，等遇到实际痛点再加 |
| BMAD | Scale-Adaptive | 有参考价值。STEP 的 Lite/Full 手动切换已够用，自动判断复杂度准确性存疑 |
| BMAD | Party Mode 多角色同时讨论 | 有趣但 opencode 不支持并行 agent 对话 |
| superpowers | 铁律极端语言（"全部删除重来"） | 可在 Agent 提示词微调时参考，不影响架构 |
| superpowers | dispatching-parallel-agents | 有价值但受限于 opencode 能力，记录为未来机会 |
| OpenSpec | 变更独立文件夹 | 不符合 STEP "聚焦单任务 TDD" 的设计假设 |
| OpenSpec | /opsx:ff 一键规划 | Lite Mode 已解决快速通道需求 |

**结论**：架构层面不需要立即借鉴。唯一的长期机会是并行 agent 分发（受限于平台能力）和 findings.md 调研记录（等痛点出现）。

---

## 八、数据汇总表

| 维度 | STEP | BMAD | OpenSpec | planning-with-files | superpowers |
|------|------|------|---------|---------------------|-------------|
| 生命周期覆盖 | ★★★★★ | ★★★★☆ | ★★★☆☆ | ★★☆☆☆ | ★★★☆☆ |
| 质量门禁强度 | ★★★★★ | ★★☆☆☆ | ★☆☆☆☆ | ★☆☆☆☆ | ★★★☆☆ |
| Session 恢复 | ★★★★★ | ★☆☆☆☆ | ★☆☆☆☆ | ★★★★☆ | ★☆☆☆☆ |
| 注意力管理 | ★★★★★ | ★☆☆☆☆ | ★☆☆☆☆ | ★★★★☆ | ★★☆☆☆ |
| 需求防漂移 | ★★★★★ | ★★☆☆☆ | ★★☆☆☆ | ★☆☆☆☆ | ★☆☆☆☆ |
| 上手门槛（低=好） | ★★★☆☆ | ★★★☆☆ | ★★★★★ | ★★★★☆ | ★★★☆☆ |
| 平台兼容性 | ★★☆☆☆ | ★★★★★ | ★★★★★ | ★★☆☆☆ | ★★☆☆☆ |
| 灵活性 | ★★★☆☆ | ★★★★☆ | ★★★★★ | ★★★★☆ | ★★☆☆☆ |
