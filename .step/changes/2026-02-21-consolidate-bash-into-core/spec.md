# Spec: Consolidate Bash Inline Node into step-core.js

> 变更类型: refactor

## 背景
step-manager.sh（934 行）中有 6 处 `node -e` 内联代码，与 step-core.js（1036 行）存在 JSON 读写、危险命令检查等功能重叠。session-start.sh 使用 `cat <<EOF`（非 `<<'EOF'`）拼接 JSON，存在 `$` 变量展开 bug。step-pretool-guard.sh 每次调用启动 4-5 个 Node 进程。此外 SKILL.md 与 WORKFLOW.md 在 Lite e2e 要求上存在矛盾。

## 需求描述

### P0: 核心技术债
1. step-manager.sh 的 14 个函数逻辑迁移到 step-core.js `manager` 子命令，step-manager.sh 改为 ~20 行薄壳
2. session-start.sh 的 JSON 输出改为 Node.js 生成（`hook session-start` 子命令），消除 `$` 转义 bug

### P1: 性能与一致性
3. step-pretool-guard.sh 改为单次 Node 调用（`guard` 子命令），从 4-5 个 Node 进程降为 1 个
4. 统一 SKILL.md 与 WORKFLOW.md 中 Lite 模式 e2e 测试要求（unit/integration 必须，e2e Full 必须 Lite 按需）

### P2: 优化
5. 消除 task_status_is 在 3 个文件中的重复定义（`task status` 子命令）
6. SKILL.md 增加分段标记，SessionStart 按 phase 分级注入
7. WORKFLOW.md 从 1507 行拆分为协议规范 (~700 行) + docs/ 下的教程、Hook 文档、设计笔记

### P3: 完善
8. 增加变更取消/放弃机制（`manager cancel` 子命令）
9. 增强 Agent dispatch 约束：Full 模式 Phase 4 下 require_dispatch=true 时拦截直接 Write/Edit，强制通过 subagent 写代码；增加 bypass 白名单
10. 优化 findings 2-Action Rule：Phase 0 保持每 2 动作更新，其他阶段改为每 4 动作或有实质发现时更新

## 影响范围
- scripts/step-core.js — 主要修改，新增 ~585 行
- scripts/step-manager.sh — 从 934 行缩减为 ~20 行薄壳
- hooks/session-start.sh — 从 173 行缩减为 ~60 行
- scripts/step-pretool-guard.sh — 从 109 行缩减为 ~30 行
- scripts/step-archive.sh, step-worktree.sh, step-stop-check.sh — 各减少 ~15 行内联 Node
- skills/step/SKILL.md, WORKFLOW.md — 文档修正与拆分
- WORKFLOW.md — 从 1507 行拆分为 ~700 行 + docs/ 下 3 个文件
- .step/config.json — 新增 enforcement.bypass_tools 字段

## 非目标
- 不拆分 step-core.js 为多个文件
- 不引入 TypeScript 或外部依赖
- 不删除 step-manager.sh 文件（保留为薄壳）
- 不修改 agent .md 文件的 prompt 内容
- 不取消 findings 机制本身

## 验收标准
- 所有现有测试通过（bash tests/test-*.sh 全部 pass）
- step-manager.sh 行数 < 30
- session-start.sh 不含 `escape_for_json` 函数
- step-pretool-guard.sh 最多启动 1 个 Node 进程
- SKILL.md 内部 e2e 规则无矛盾
- WORKFLOW.md 行数 < 800
- docs/examples.md、docs/hooks.md、docs/design-notes.md 存在且非空
- Full 模式 Phase 4 下 require_dispatch=true 时直接 Write/Edit 被拦截
- Phase 0 findings 阈值=2，Phase 4 findings 阈值=4

## 决策记录
- decision: accepted (ADR-006)
- decided_by: "step-architect + step-reviewer"
- decided_at: "2026-02-22"
