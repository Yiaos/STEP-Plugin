# STEP vs. 同类工具对比分析

> 本文档对比 STEP Protocol 与四个主流 AI 编码代理开发框架/工具，分析各自的设计哲学、覆盖范围和适用场景。

---

## 一、各工具概览

| | STEP | BMAD-METHOD | OpenSpec | planning-with-files | superpowers |
|---|---|---|---|---|---|
| **定位** | 全生命周期开发协议 + opencode 插件 | AI 驱动的敏捷开发框架 | Spec 驱动开发 (SDD) | 文件驱动的计划管理 | 工程纪律技能套件 |
| **Stars** | — (新项目) | 35.6k | 24.1k | — (opencode 内置) | — (opencode 内置) |
| **安装方式** | `bash install.sh` (opencode 插件) | `npx bmad-method install` (npm) | `npm install -g @fission-ai/openspec` → `openspec init` | opencode skill (内置) | opencode skill (内置) |
| **支持平台** | opencode | Claude Code, Cursor, Windsurf 等 | 20+ AI 编码工具 | opencode | opencode |
| **核心哲学** | 状态机 + 硬门禁 + Session 恢复 | 多 Agent 协作 + Scale-Adaptive | 先规范后编码，流动迭代 | 文件系统作外部 RAM | 铁律纪律，禁止走捷径 |

---

## 二、生命周期覆盖对比

| 阶段 | STEP | BMAD | OpenSpec | planning-with-files | superpowers |
|------|------|------|---------|---------------------|-------------|
| **需求发现/头脑风暴** | ✅ Phase 0 Discovery | ✅ product-brief, brainstorming | ⚠️ proposal.md (轻量) | ❌ 不覆盖 | ✅ brainstorming skill |
| **需求定义/PRD** | ✅ Phase 1 PRD → baseline.md | ✅ create-prd (完整 PRD) | ✅ specs/ 目录 | ❌ 不覆盖 | ❌ 不覆盖 |
| **技术设计/架构** | ✅ Phase 2 Tech Design → ADR | ✅ create-architecture | ✅ design.md | ❌ 不覆盖 | ❌ 不覆盖 |
| **任务规划/拆分** | ✅ Phase 3 Plan → BDD 场景矩阵 | ✅ create-epics-and-stories | ✅ tasks.md | ✅ task_plan.md | ✅ writing-plans skill |
| **执行/编码** | ✅ Phase 4 Execution (TDD) | ✅ dev-story | ✅ opsx:apply | ✅ 持续进度同步 | ✅ TDD + executing-plans |
| **测试策略** | ✅ BDD 场景 + unit/integration/e2e | ⚠️ Quinn(内置) / TEA(模块) | ❌ 无测试机制 | ❌ 不覆盖 | ✅ test-driven-development |
| **质量门禁** | ✅ gate.sh (lint+type+test+build) | ⚠️ code-review workflow | ❌ 无门禁 | ❌ 无门禁 | ✅ verification-before-completion |
| **代码审查** | ✅ Phase 5 Review | ✅ code-review | ❌ 不覆盖 | ❌ 不覆盖 | ✅ requesting/receiving-code-review |
| **Session 恢复** | ✅ SessionStart Hook 自动注入 | ❌ 靠人工重新加载 | ❌ 不覆盖 | ✅ session-catchup.py | ❌ 不覆盖 |
| **Post-MVP 变更** | ✅ CR / Hotfix / 约束变更 | ✅ sprint 迭代 | ✅ archive + 新 change | ❌ 不覆盖 | ❌ 不覆盖 |
| **需求防漂移** | ✅ baseline 确认 + CR 机制 | ⚠️ PRD 作参考文档 | ⚠️ proposal 无确认 | ❌ 不覆盖 | ❌ 不覆盖 |

**覆盖度评分**: STEP ≈ 11/11 | BMAD ≈ 9/11 | OpenSpec ≈ 6/11 | planning-with-files ≈ 3/11 | superpowers ≈ 6/11

---

## 三、角色/Agent 系统对比

### STEP: 7 个精简角色

| 角色 | 阶段 | 模型 |
|------|------|------|
| PM | Phase 0-1 | claude-opus |
| Architect | Phase 2-3 | claude-opus |
| QA | Phase 3/4/5 | claude-opus |
| Developer | Phase 4 | codex |
| Designer | Phase 2/3/4 | claude-opus |
| Reviewer | Phase 5 | claude-opus |
| Deployer | Phase 4/5 | claude-opus |

**设计哲学**: 精简 7 角色 × 明确制衡。PM 定义"做什么"、Architect 定义"怎么做"、Designer 负责体验与界面、QA 定义"怎么破坏它"、Developer 只做被定义的事、Reviewer 独立审查交付物、Deployer 定义部署策略。每个角色绑定 opencode agent 定义文件（`agents/*.md`），通过 subagent 机制实现模型路由。

### BMAD: 12+ 专业 Agent + Party Mode

核心 Agent：Analyst, PM, Architect, Developer, UX Designer, Scrum Master, QA (Quinn), Code Reviewer, DevOps, Data Modeler, Technical Writer, BMad Help 等。

**设计哲学**: 每个工作流有最佳 Agent，Agent 有专业知识和菜单系统。Party Mode 允许在一个 session 中同时引入多个 Agent 角色进行讨论。Scale-Adaptive 自动调整规划深度。

**对比**:
- BMAD 角色更多，覆盖面广（包含 UX、DevOps、Data Modeling 等 STEP 不涉及的领域）
- STEP 角色更精简，但有**硬性模型绑定**（通过 opencode agent 文件），BMAD 的 Agent 是 prompt 层面的 persona 切换
- BMAD 的 Party Mode 是独特优势（多角色同时参与讨论）
- STEP 的角色制衡更严格（QA 对抗性审查，Developer 不可越界）

### OpenSpec / planning-with-files / superpowers

无专门角色系统。superpowers 通过技能链条隐式实现类似效果（brainstorming 引导设计、TDD 引导实现、code-review 引导审查），但不是结构化角色。

---

## 四、执行保证机制对比

| 机制类型 | STEP | BMAD | OpenSpec | planning-with-files | superpowers |
|---------|------|------|---------|---------------------|-------------|
| **可执行脚本** | ✅ gate.sh, scenario-check.sh | ❌ | ❌ | ❌ | ❌ |
| **自动 Hook** | ✅ SessionStart Hook | ❌ | ❌ | ⚠️ pre/post 工具调用钩子 | ⚠️ 1% 触发规则 |
| **Agent 模型绑定** | ✅ agents/*.md → 不同模型 | ❌ 同模型 persona | ❌ | ❌ | ❌ |
| **BDD 场景 ID 绑定** | ✅ `[S-xxx-xx]` 硬匹配 | ❌ | ❌ | ❌ | ❌ |
| **文件模板强制** | ✅ step-init.sh 确定性创建 | ✅ npx install 生成 | ✅ openspec init 生成 | ⚠️ 手动创建 3 文件 | ❌ |
| **状态机** | ✅ state.yaml (Phase 流转) | ❌ | ❌ | ⚠️ task_plan.md 手动维护 | ❌ |

### 硬保证 vs 软保证

**STEP 硬保证**:
1. `gate.sh` / `scenario-check.sh` — 脚本执行结果确定性
2. subagent 模型绑定 — `agents/*.md` 启动时确定
3. SessionStart Hook 注入 — 有 `.step/` 就一定触发
4. 文件模板结构 — `step-init.sh` 确定性创建

**STEP 软保证（也是所有同类工具的共同局限）**:
- Phase 流转顺序、TDD 先测后写、每次跑 gate、baseline 确认 — 均依赖 LLM 遵守 prompt

**BMAD**: 全部是 prompt 级保证（Agent persona + workflow 引导），无可执行脚本门禁

**OpenSpec**: 无门禁机制，哲学是"流动不僵硬"，允许随时修改任何 artifact

**planning-with-files**: 2-Action 规则 + 三振出局协议（prompt 级），session-catchup.py 是唯一的硬机制

**superpowers**: 铁律措辞极强（"严禁"、"全部删除重来"），但本质仍是 prompt 级约束

---

## 五、Session 恢复对比

| | STEP | BMAD | OpenSpec | planning-with-files | superpowers |
|---|---|---|---|---|---|
| **恢复机制** | SessionStart Hook 自动读取 state.yaml | 无（需人工重新加载 Agent） | 无（spec 文件在磁盘但不自动注入） | session-catchup.py 脚本 | 无 |
| **恢复精度** | Phase + Task + Status + next_action | — | — | 3 个 MD 文件内容 | — |
| **自动化程度** | 全自动（Hook 触发） | 手动 | 手动 | 半自动（需运行脚本） | — |
| **防漂移** | baseline.md 确认 + CR 机制 | PRD 文档（无确认） | proposal（无确认） | task_plan.md（无确认） | — |

**结论**: Session 恢复是 STEP 和 planning-with-files 的核心优势。STEP 通过 Hook 全自动注入，planning-with-files 需手动运行脚本。其余工具不涉及此问题。

---

## 六、适用场景对比

| 场景 | 最佳选择 | 原因 |
|------|---------|------|
| **全新 MVP 产品（需求→上线）** | STEP 或 BMAD | 全生命周期覆盖 |
| **已有代码库的新功能** | STEP 或 OpenSpec | STEP 有已有项目检测；OpenSpec brownfield 友好 |
| **大型企业项目（多人协作）** | BMAD | Scale-Adaptive + 更多角色覆盖 |
| **快速原型 / 小功能** | OpenSpec | 轻量，`/opsx:ff` 快速生成所有规划文档 |
| **复杂调研 / 长期重构** | planning-with-files | 极强的上下文持久化 |
| **严肃的生产代码质量** | STEP + superpowers | STEP 提供结构，superpowers 提供纪律 |
| **Bug 修复 / 小改动** | superpowers (systematic-debugging) | 根因分析 + TDD 修复 |
| **跨 Session 长期开发** | STEP | 唯一有全自动 Session 恢复的方案 |

---

## 七、核心差异总结

### STEP 相对优势
1. **唯一有可执行质量门禁**（gate.sh + scenario-check.sh 是真实脚本，不是 checklist）
2. **唯一有 BDD 场景矩阵 + ID 绑定**（`[S-xxx-xx]` 硬匹配验证覆盖率）
3. **唯一有全自动 Session 恢复**（SessionStart Hook，无需人工操作）
4. **唯一有需求确认 + CR 机制**（baseline.md 确认后变更需走 Change Request）
5. **唯一有 Agent 模型路由**（7 个角色绑定不同模型，通过 opencode subagent 实现）

### STEP 相对劣势
1. **平台绑定 opencode** — BMAD 支持 Claude Code/Cursor/Windsurf，OpenSpec 支持 20+ 工具
2. **角色数量少** — BMAD 有 12+ 专业 Agent（UX、DevOps 等 STEP 不覆盖）
3. **社区和生态** — BMAD 35k stars + 111 contributors + Discord + npm 模块市场；STEP 刚起步
4. **Scale-Adaptive 缺失** — BMAD 根据项目复杂度自动调整规划深度，STEP 是固定 6 阶段
5. **不如 OpenSpec 轻量** — OpenSpec 的 `/opsx:ff` 可以一键生成所有规划文档，STEP 每个阶段需逐步推进

### 互补组合建议

| 组合 | 效果 |
|------|------|
| **STEP + superpowers** | STEP 提供全生命周期结构 + 门禁，superpowers 在每个编码节点提供铁律纪律。**最强质量保证**。 |
| **STEP + planning-with-files** | STEP 管 Phase 流转 + 门禁，planning-with-files 在超长 session 中持久化细节上下文。**最强记忆**。 |
| **OpenSpec + STEP (Phase 4-5)** | OpenSpec 快速规划（proposal → specs → tasks），STEP 接管执行阶段（TDD + gate + review）。**速度 + 质量平衡**。 |

---

## 八、数据汇总表

| 维度 | STEP | BMAD | OpenSpec | planning-with-files | superpowers |
|------|------|------|---------|---------------------|-------------|
| 生命周期覆盖 | ★★★★★ | ★★★★☆ | ★★★☆☆ | ★★☆☆☆ | ★★★☆☆ |
| 质量门禁强度 | ★★★★★ | ★★☆☆☆ | ★☆☆☆☆ | ★☆☆☆☆ | ★★★★☆ |
| Session 恢复 | ★★★★★ | ★☆☆☆☆ | ★☆☆☆☆ | ★★★★☆ | ★☆☆☆☆ |
| 上手门槛（低=好） | ★★★☆☆ | ★★★☆☆ | ★★★★★ | ★★★★☆ | ★★★☆☆ |
| 平台兼容性 | ★★☆☆☆ | ★★★★★ | ★★★★★ | ★★☆☆☆ | ★★☆☆☆ |
| 社区生态 | ★☆☆☆☆ | ★★★★★ | ★★★★☆ | ★★☆☆☆ | ★★☆☆☆ |
| 灵活性 | ★★★☆☆ | ★★★★☆ | ★★★★★ | ★★★★☆ | ★★☆☆☆ |
| 需求防漂移 | ★★★★★ | ★★☆☆☆ | ★★☆☆☆ | ★☆☆☆☆ | ★☆☆☆☆ |
