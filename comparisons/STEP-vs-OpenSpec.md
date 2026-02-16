# STEP vs OpenSpec 详细对比

> 基于 STEP baseline v2（2026-02-16）重新对比。

## 1. 定位差异

**STEP**："状态机 + 硬门禁 + 角色对抗"。6 阶段生命周期严格流转，脚本级门禁 + 三层 Hook + 7 角色对抗。哲学：结构优先，约束驱动。

**OpenSpec**："流动 + 迭代"。Spec-driven development (SDD)，`fluid not rigid, iterative not waterfall, easy not complex`。无阶段门禁，随时修改任何 artifact。哲学：先达成共识，再写代码。

| | STEP | OpenSpec |
|---|---|---|
| 核心假设 | LLM 会偷懒、跳过边界 → 需要门禁阻断 | LLM 需要清晰规范 → 给好 spec 就够了 |
| 约束风格 | 硬性（脚本阻断 + Hook 注入 + 角色对抗） | 柔性（文档约定，随时可改） |
| 适配对象 | opencode | 20+ AI 编码工具 |

## 2. 工作流对比

### OpenSpec

```
/opsx:new <name>     → 创建变更文件夹
/opsx:ff             → 一键生成所有规划文档
/opsx:apply          → 执行任务
/opsx:archive        → 归档完成的变更
```

特点：`/opsx:ff` 一键生成全部规划文档（proposal + specs + design + tasks）。无阶段门禁，随时回到任何文档修改。每个变更独立文件夹。

### STEP

```
/step                → 初始化或恢复
Phase 0 Discovery    → 开放式讨论
Phase 1 PRD          → baseline.md 确认
Phase 2 Tech Design  → ADR 记录
Phase 3 Plan & Tasks → BDD 场景矩阵
Phase 4 Execution    → TDD + gate 检查点
Phase 5 Review       → 需求合规审查
```

特点：每阶段有入口/出口条件。Phase 0/2 开放讨论，Phase 1/3 结构化确认。Phase 4 有 TDD + gate 脚本级检查点。Lite Mode 提供 3 阶段快速通道。

| 维度 | STEP | OpenSpec |
|------|------|---------|
| 流转方式 | 顺序阶段（可 Lite 快速通道） | 自由命令组合 |
| 门禁 | gate.sh + scenario-check.sh | 无 |
| 速度 | 逐阶段推进（Lite 更快） | /opsx:ff 一键 |
| 灵活性 | 阶段约束（Full）/ 快速通道（Lite） | 随时修改 |

## 3. Artifact 管理对比

### OpenSpec
```
openspec/changes/add-dark-mode/
├── proposal.md    # 为什么做
├── specs/         # 需求和场景
├── design.md      # 技术方案
└── tasks.md       # 实现清单
```
特点：每变更独立文件夹，支持并行开发多个功能。

### STEP
```
.step/
├── config.yaml      # 模型路由 + gate 配置
├── state.yaml       # 状态机（倒序，最新在前）
├── baseline.md      # 需求基线（活快照）
├── decisions.md     # ADR 日志
├── changes/         # 统一变更目录（spec + design + tasks）
├── evidence/        # gate 运行证据
└── archive/         # 历史版本归档
```
特点：全局状态机 + 变更目录（init 与后续变更统一结构）。archive/ 归档历史版本。Baseline 整理流程保持文件干净。

| 维度 | STEP | OpenSpec |
|------|------|---------|
| 组织方式 | 全局状态 + 变更目录（spec/design/tasks） | 按变更独立文件夹 |
| 需求表达 | baseline.md（全局确认） + tasks YAML（BDD） | proposal.md + specs/ |
| 状态追踪 | state.yaml（机器可读，倒序） | tasks.md checkbox |
| 归档 | archive/ + Baseline 整理流程 | archive/ 按日期 |
| 并行功能 | 支持（多变更文件夹） | 支持（多变更文件夹） |

## 4. 执行阶段对比

| 维度 | STEP Phase 4 | OpenSpec /opsx:apply |
|------|-------------|---------------------|
| TDD | ✅ QA 先写测试 → Developer 写实现 | ❌ |
| 质量门禁 | ✅ gate.sh (lint + typecheck + test + build) | ❌ |
| 场景覆盖 | ✅ scenario-check.sh [S-xxx-xx] 硬匹配 | ❌ |
| 模型路由 | ✅ 测试/前端/后端用不同模型 | ❌ 推荐但不强制 |
| 检查点 | ✅ 每场景跑 gate quick，全部通过跑 standard | ❌ |
| Gate 失败处理 | ✅ 根因分析 → 3 轮 → blocked | ❌ |
| Review | ✅ Phase 5 Reviewer agent | ❌ |

这是最大差距：OpenSpec 在执行阶段几乎没有质量保证机制。

## 5. 需求管理对比

### STEP
- Phase 1 起草 baseline.md → 分段确认 → 用户确认
- 确认后修改 → 必须新建变更（changes/）→ 审计记录
- Baseline 整理：多轮变更后归档旧版 → 合成干净快照 → 同时精简 state.yaml + decisions.md

### OpenSpec
- /opsx:new → proposal.md 起草
- 随时修改 proposal/specs/design/tasks
- 无确认、无变更审计

STEP 适合需要变更追溯的场景；OpenSpec 适合个人快速迭代。

## 6. 平台兼容性

| | STEP | OpenSpec |
|---|---|---|
| 平台 | opencode 唯一 | 20+ 工具 |
| 安装 | bash install.sh | npm install -g |
| 社区 | 新项目 | 24k+ stars, 46+ contributors |

OpenSpec 的最大优势是平台兼容性。

## 7. 可借鉴点

| OpenSpec 特性 | 评估 |
|-------------|------|
| /opsx:ff 一键规划 | Lite Mode（L1 Quick Spec → L2 Execution → L3 Review）已解决快速通道需求。不应为了速度牺牲确认环节 |
| 变更独立文件夹 | 不符合 STEP "聚焦单任务 TDD" 的设计假设。并行开发多个功能不是 STEP 的目标场景 |
| 20+ 平台支持 | 长期方向可考虑协议层与平台解耦（NG-2 已声明此为非目标但保持解耦） |
| archive 归档机制 | STEP 已有 archive/ 目录 + /archive 命令 + Baseline 整理流程 |

## 8. OpenSpec 缺少什么

1. 可执行门禁脚本
2. TDD 机制 + BDD 场景矩阵
3. Session 恢复
4. 需求确认 + 变更审计
5. 角色系统 + 模型绑定
6. 结构化状态机
7. 代码审查阶段
8. 注意力管理 Hook
9. Gate 失败分级处理

## 9. 总结

OpenSpec 是"轻快的规划工具"，STEP 是"严谨的执行协议"。OpenSpec 赢在速度、灵活性和平台兼容性；STEP 赢在执行保证、需求防漂移和 Session 恢复。两者在架构层面不冲突——理论上可以用 OpenSpec 快速规划，再用 STEP 接管执行阶段（但实际操作中 artifact 格式不兼容，需要手动转换）。
