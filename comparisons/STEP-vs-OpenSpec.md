# STEP vs OpenSpec 详细对比

本文对比 STEP Protocol 与 OpenSpec 的定位、工作流、质量保证与平台兼容性，给出适用场景建议。

## 1. 定位与哲学差异

**STEP**："状态机 + 硬门禁"。6 阶段生命周期严格流转，通过可执行脚本、BDD 场景覆盖和 SessionStart Hook 保证"可验证完成"。哲学是：**结构优先，约束驱动**。

**OpenSpec**："流动 + 迭代"。Spec-driven development (SDD)，核心信条是 `fluid not rigid, iterative not waterfall, easy not complex`。允许随时修改任何 artifact，无阶段门禁。哲学是：**先达成共识，再写代码**。

| | STEP | OpenSpec |
|---|---|---|
| 核心假设 | LLM 会偷懒、跳过边界 → 需要门禁阻断 | LLM 需要清晰规范 → 给好 spec 就够了 |
| 约束风格 | 硬性（脚本阻断 + Hook 注入） | 柔性（文档约定，随时可改） |
| 适配对象 | opencode | 20+ AI 编码工具 |

## 2. 工作流对比

### OpenSpec 的 Slash Command 流

```
/opsx:new <name>     → 创建变更文件夹
/opsx:ff             → 一键生成所有规划文档（proposal + specs + design + tasks）
/opsx:apply          → 执行任务
/opsx:archive        → 归档完成的变更
```

**特点**：
- `/opsx:ff`（fast-forward）是杀手级功能——一个命令生成全部规划文档
- 无阶段门禁，可以随时回到任何文档修改
- 每个变更独立一个文件夹，互不干扰

### STEP 的 6 阶段流

```
/step                → 初始化或恢复
Phase 0 Discovery    → 开放式讨论
Phase 1 PRD          → 选择题确认 → baseline.md 确认
Phase 2 Tech Design  → 开放式讨论 → ADR 记录
Phase 3 Plan & Tasks → BDD 场景矩阵 → 用户审核
Phase 4 Execution    → TDD → gate.sh → Review → Commit
Phase 5 Review       → 需求合规 > 代码质量
```

**特点**：
- 每个 Phase 有明确的入口/出口条件
- Phase 0/2 开放讨论，Phase 1/3 结构化确认——两种对话模式
- Phase 4 有 TDD 循环 + gate 门禁
- 不能跳过阶段（软保证）

### 核心差异

| 维度 | STEP | OpenSpec |
|------|------|---------|
| 流转方式 | 顺序阶段（Phase 0→5） | 自由命令组合 |
| 门禁 | Phase 间有条件、Phase 4 有 gate.sh | 无门禁 |
| 速度 | 逐阶段推进，较慢但严谨 | `/opsx:ff` 一键生成，极快 |
| 灵活性 | 低（阶段约束） | 高（随时修改任何文档） |

## 3. Artifact 管理对比

### OpenSpec 的变更文件夹

```
openspec/
├── changes/
│   ├── add-dark-mode/
│   │   ├── proposal.md    # 为什么做、改什么
│   │   ├── specs/         # 需求和场景
│   │   ├── design.md      # 技术方案
│   │   └── tasks.md       # 实现清单
│   └── archive/
│       └── 2025-01-23-add-dark-mode/  # 归档
└── openspec.config.*      # 配置
```

**特点**：每个功能/变更独立文件夹，完成后归档。适合并行开发多个功能。

### STEP 的 `.step/` 目录

```
.step/
├── config.yaml          # 模型路由 & gate 命令
├── state.yaml           # 状态机（当前阶段 + 任务 + next_action）
├── baseline.md          # 需求基线（确认）
├── decisions.md         # 架构决策日志 (ADR)
├── tasks/               # 任务 YAML + BDD 场景矩阵
│   └── T-001-auth.yaml  # 含 happy_path / edge_cases / error_handling
├── change-requests/     # 变更请求
└── evidence/            # gate 运行证据
```

**特点**：全局状态机 + 任务级 BDD 场景。适合单一 MVP 的端到端开发。

### 对比

| 维度 | STEP | OpenSpec |
|------|------|---------|
| 组织方式 | 全局状态 + 任务 YAML | 按变更独立文件夹 |
| 需求表达 | baseline.md（全局） + task YAML（BDD 场景） | proposal.md + specs/（每变更独立） |
| 技术设计 | decisions.md（ADR 日志） | design.md（每变更独立） |
| 状态追踪 | state.yaml（机器可读） | tasks.md 中的 checkbox |
| 归档 | 无（任务标 done 在 state.yaml） | archive/ 目录（按日期归档） |
| 并行功能 | 不支持（单任务流） | 支持（多个 change 文件夹） |

## 4. 执行阶段对比

### OpenSpec 的 `/opsx:apply`

- 按 tasks.md 中的任务逐项实现
- 没有强制测试要求
- 没有质量门禁
- 完成后 `/opsx:archive` 归档

### STEP 的 Phase 4 Execution

```
Step 1: 加载上下文 → 输出状态行
Step 2: 写测试（按 routing.test_writing 派发 @step-qa） → 确认全部 FAIL (TDD RED)
Step 3: 写实现（按 file_routing 选 agent） → 每场景跑 gate quick
Step 4: Gate 验证 → gate.sh standard {slug}
Step 5: Review + Commit
Step 6: 更新 state.yaml → 进入下一任务
```

| 维度 | STEP Phase 4 | OpenSpec /opsx:apply |
|------|-------------|---------------------|
| TDD | ✅ 强制先写测试 | ❌ 无 |
| 质量门禁 | ✅ gate.sh (lint + typecheck + test + build) | ❌ 无 |
| 场景覆盖验证 | ✅ scenario-check.sh | ❌ 无 |
| 模型路由 | ✅ 测试/前端/后端用不同模型 | ❌ 推荐模型但不强制 |
| 每任务 Review | ✅ Phase 5 Review | ❌ 无 |

**这是最大差距**：OpenSpec 在执行阶段几乎没有质量保证机制。

## 5. 质量保证机制

| 机制 | STEP | OpenSpec |
|------|------|---------|
| 可执行门禁脚本 | ✅ gate.sh (lint + typecheck + test + build) | ❌ |
| BDD 场景覆盖验证 | ✅ scenario-check.sh (场景 ID 硬匹配) | ❌ |
| TDD 强制 | ✅ 先写测试、确认 FAIL、再实现 | ❌ |
| 代码审查 | ✅ Phase 5 Review (需求合规 > 代码质量) | ❌ |
| Gate 失败处理 | ✅ 强模型分析根因 → 最多 3 轮自动修复 | ❌ |
| 模型路由 | ✅ 测试和实现用不同模型（对抗性） | ❌ |

**结论**：OpenSpec 的哲学是"spec 写好了，实现自然就对了"。STEP 的哲学是"spec 写好了还不够，必须有门禁验证"。

## 6. 需求管理与防漂移

### STEP：确认 + CR 机制

```
Phase 1: baseline.md 起草 → 分段确认 → 确认
         确认后修改 → 必须提交 Change Request
         CR 确认 → 更新 baseline → 新 task YAML → 重新执行
```

**保证强度**：baseline.md 确认是契约（非文件锁），Change Request 是结构化流程。

### OpenSpec：proposal 无确认机制

```
/opsx:new → proposal.md 起草
           随时可以修改 proposal、specs、design、tasks
            无确认、无 CR 机制
```

**保证强度**：无。哲学是 "fluid not rigid"。

**对比**：STEP 更适合需求变更需要变更追溯的场景（团队协作、客户交付）；OpenSpec 更适合个人开发或快速迭代。

## 7. 平台兼容性

**这是 OpenSpec 的最大优势**。

| | STEP | OpenSpec |
|---|---|---|
| 支持平台 | opencode 唯一 | 20+ AI 编码工具 |
| 安装方式 | `bash install.sh`（opencode 插件） | `npm install -g @fission-ai/openspec` |
| 生态 | opencode 内部 | npm 包，独立于任何 IDE |
| 社区 | 新项目 | 24.1k stars, 46 contributors, Discord |

OpenSpec 支持的工具：Claude Code, Cursor, Windsurf, Copilot, Cline, Aider, Continue, Zed, Codex 等 20+。

STEP 深度绑定 opencode 的 Hook、subagent、skill 机制。移植到其他平台需要重新实现这些基础设施。

## 8. 已有项目支持

两者都声称 brownfield-friendly：

**STEP**：`step-init.sh` 扫描 14 种清单文件 + 10 种源码目录 + 6 种测试目录 + git，检测到已有代码后输出 LLM 指令，引导先分析现有代码结构再构建 baseline。

**OpenSpec**：`openspec init` 在项目中创建 `openspec/` 目录。哲学层面强调 "built for brownfield not just greenfield"。每个变更独立文件夹，不需要理解全量代码。

| 维度 | STEP | OpenSpec |
|------|------|---------|
| 代码分析 | ✅ 自动检测并引导分析 | ❌ 不主动分析 |
| 增量友好 | ⚠️ 全局 baseline，新功能需整合 | ✅ 每变更独立文件夹 |
| 适合场景 | 接手已有项目做系统性改进 | 在已有项目上快速加功能 |

## 9. STEP 可以借鉴什么

| OpenSpec 特性 | 描述 | STEP 可以如何吸收 |
|-------------|------|----------------|
| **`/opsx:ff` 一键规划** | 一个命令生成 proposal + specs + design + tasks | 考虑 `/step fast` 命令快速生成 baseline + tasks |
| **变更独立文件夹** | 每个功能/变更独立目录，互不干扰 | Post-MVP CR 可以借鉴此模式 |
| **归档机制** | `/opsx:archive` 按日期归档 | STEP 的 evidence/ 可以扩展为任务归档 |
| **20+ 平台支持** | 通过 slash commands 适配多平台 | 长期可考虑 CLI 工具 + 多平台适配 |
| **轻量哲学** | 不过度约束，快速上手 | 考虑 STEP lite 模式（跳过部分阶段） |

## 10. OpenSpec 缺少什么

1. **质量门禁** — 没有 gate.sh 或任何可执行的质量检查脚本
2. **测试机制** — 没有 TDD 强制、BDD 场景矩阵、覆盖率验证
3. **Session 恢复** — 没有 SessionStart Hook 或任何自动状态恢复
4. **需求确认** — proposal.md 无确认，无 Change Request 流程
5. **角色系统** — 没有 STEP 的 7 角色分工与模型绑定
6. **状态机** — tasks.md 是 checkbox，不是结构化 state.yaml
7. **代码审查** — 没有独立的 Review 阶段
8. **模型路由** — 推荐模型但不绑定，无对抗性测试机制

## 11. 总结：什么时候选哪个

| 场景 | 推荐 | 原因 |
|------|------|------|
| **快速加功能（已有项目）** | OpenSpec | `/opsx:ff` 一键规划，轻量不侵入 |
| **全新 MVP 产品** | STEP | 全生命周期管理 + 门禁保证质量 |
| **团队协作/客户交付** | STEP | 需求确认 + CR 机制 + Review 阶段 |
| **个人项目快速迭代** | OpenSpec | 灵活、快速、无约束 |
| **质量敏感（金融/医疗）** | STEP | gate.sh + BDD 场景 100% 覆盖 |
| **多工具平台团队** | OpenSpec | 20+ 工具支持 |
| **跨 Session 长期开发** | STEP | SessionStart Hook 自动恢复 |
| **探索性开发/原型** | OpenSpec | 随时修改，无阶段约束 |

### 组合使用

```
OpenSpec 负责快速规划（proposal → specs → tasks）
     ↓
STEP 接管执行阶段（Phase 4 TDD + gate + Phase 5 Review）
```

OpenSpec 的 `/opsx:ff` 速度 + STEP 的 gate.sh 质量 = 速度与质量的平衡。

**一句话**：OpenSpec 是"轻快的规划工具"，STEP 是"严谨的执行协议"。选择取决于你更担心"规划不够快"还是"执行质量不够硬"。
