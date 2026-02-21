# Baseline

> 状态: ✅ 活快照（整理自 v1，2026-02-15）

## Goal
为 AI 编码代理提供全生命周期开发协议（STEP），通过阶段化流程、可执行门禁和会话恢复机制保证交付质量。

## Non-Goal（明确不做的事）
- NG-1: 不替代 IDE 或编辑器功能
- NG-2: 不固定绑定特定 LLM 平台（当前基于 opencode，但协议层与平台解耦）

## 已实现能力

### 协议流程（6 阶段）
- [x] Phase 0 Discovery — 开放式讨论，用户主导方向
- [x] Phase 1 PRD — 分段展示 baseline.md 草稿，选择题确认
- [x] Phase 2 Tech Design — 开放式讨论技术方案，LLM 提供对比分析
- [x] Phase 3 Plan & Tasks — BDD 场景矩阵 + 任务依赖图，用户审核
- [x] Phase 4 Execution — TDD 循环（QA 写测试 + Developer 写实现）+ Gate 验证
- [x] Phase 5 Review — 独立审查（需求合规 > 代码质量）+ Commit

### 角色体系（7 角色）
- [x] PM — Phase 0/1，需求探索与 baseline 确认
- [x] Architect — Phase 2/3，技术方案与任务拆分
- [x] QA — Phase 3 场景补充 / Phase 4 测试编写 / Gate 失败分析
- [x] Developer — Phase 4 后端实现
- [x] Designer — Phase 2 UI 设计 / Phase 4 前端实现 / Polish 检查
- [x] Reviewer — Phase 5 代码审查
- [x] Deployer — 部署策略建议（可选）

### 质量门禁（可执行脚本）
- [x] gate.sh — lint / typecheck / test / build，三级：quick / lite / full
- [x] scenario-check.sh — BDD 场景 ID 硬匹配，100% 覆盖验证
- [x] step-stop-check.sh — 会话结束前检查 state.json 更新状态

### 注意力管理
- [x] PreToolUse hook — state.json 头部嵌入行为规则，cat | head -25 同时注入规则和数据
- [x] PostToolUse hook — 每次 Write/Edit 后提醒检查状态变化
- [x] Stop hook — 脚本检查 last_updated / progress_log（pass/warn/fail）
- [x] SKILL.md 注意力规则 — Pre-decision Read + 三层 Hook 注入 + HARD-GATE 标签 + 验证铁律
- [x] SessionStart hook — 自动检测 .step/ 并注入完整上下文（state + task + baseline + config + SKILL）

### 会话恢复
- [x] state.json 状态机 — current_phase / progress_log / next_action / key_decisions
- [x] SessionStart hook 自动注入 — 有 .step/ 就注入，无需用户手动恢复

### 执行模式
- [x] Full Mode — 6 阶段完整流程
- [x] Lite Mode — 3 阶段快速通道（L1 Quick Spec → L2 Execution → L3 Review）
- [x] Lite 批量处理 — 一次提交多个小任务，逐个 TDD + gate + commit
- [x] Lite → Full 升级 — 执行中发现复杂度超预期时自动升级

### Post-MVP 流程（统一变更结构）
- [x] 新增功能 — changes/YYYY-MM-DD-{slug}/（spec + design + tasks）
- [x] Hotfix — changes/YYYY-MM-DD-{slug}-hotfix/（spec + tasks）
- [x] 约束变更 — 高影响变更 + 影响分析 + 迁移任务
- [x] Baseline 整理 — 多轮变更后归档旧版 + 合成干净快照

### 防漂移机制
- [x] baseline 活快照 + 变更审计链（changes/ + archive/）
- [x] decisions.md ADR 日志
- [x] 角色分离与对抗性（QA 写测试 ≠ Developer 写实现）
- [x] Gate 失败分级处理（根因分析 → 3 轮上限 → blocked）

### 插件基础设施
- [x] install.sh — 安装/强制重装
- [x] uninstall.sh — 卸载（插件或项目）
- [x] step-init.sh — 项目初始化 + 16 种包管理器检测
- [x] /step 命令 — 初始化或恢复 session
- [x] /archive 命令 — 变更归档
- [x] config.json — Agent 路由 + 文件路由 + Gate 命令配置
- [x] 模板体系 — state.json / baseline.md / decisions.md / findings.md / spec.md / design.md / task.md / lite-task.md / config.json
- [x] 统一变更结构 — changes/{change}/（spec.md + design.md + tasks/），初始开发和后续变更结构统一

### 文档
- [x] WORKFLOW.md — 完整协议规范
- [x] SKILL.md — 核心规则速查
- [x] 5 份对比文档 — vs planning-with-files / BMAD / OpenSpec / superpowers / 综合对比表

## Constraints（不可违反约束）
- C-1: 所有脚本兼容 macOS (bash 3.2+) 和 Linux (bash 4+)
- C-2: state.json 模板向后兼容（新字段有默认值）
- C-3: install.sh 必须能正确安装所有文件
- C-4: test_writing model 通过 config.json 配置，不硬编码
- C-5: baseline 变更通过新建变更（changes/），方向性变更走 Phase 0-1

## 架构决策（ADR 索引）
- ADR-005: Baseline 语义 — 活快照
- ADR-001: state.json 头部嵌入行为规则
- ADR-002: Stop hook 改为独立脚本
- ADR-003/004: 移除 research/ 目录和 session-catchup

详见 `.step/decisions.md`，完整历史见 `.step/archive/`。

## 状态
- 整理时间: 2026-02-16
- 整理自: v1
- 修改方式: 必须通过新建变更（`.step/changes/YYYY-MM-DD-{slug}/`）
