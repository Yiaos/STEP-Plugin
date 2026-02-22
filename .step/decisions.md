# Architecture Decision Log

> 整理自 v1（2026-02-16）。完整历史见 .step/archive/2026-02-16-decisions-v1.md

## ADR-005: Baseline 语义 — 活快照
- **日期**: 2026-02-15
- **状态**: accepted
- **决策**: baseline 是"活快照"，首版确认后受 CR 保护，任务完成+用户确认后可更新。CR 是审计记录（recorded/reverted），不是审批门禁
- **理由**: 文件系统无写保护，冻结语义与现实矛盾
- **替代方案**: 保持冻结语义 → CR 流程被忽略

## ADR-001: state.json 头部嵌入行为规则
- **日期**: 2026-02-15
- **状态**: accepted
- **决策**: state.json 头部增加 ⚡ 行为规则注释，PreToolUse hook 通过 `cat | head -25` 同时注入规则和数据
- **理由**: 混合规则+数据的注入方式 LLM 遵循率更高
- **替代方案**: 单独 rules.txt → 多一次 IO

## ADR-002: Stop hook 改为独立脚本
- **日期**: 2026-02-15
- **状态**: accepted
- **决策**: step-stop-check.sh 检查 last_updated 和 progress_log，输出 pass/warn/fail
- **理由**: 从 echo 软提醒升级为脚本中等保证，与 gate.sh 对齐
- **替代方案**: 内联 bash 到 SKILL.md frontmatter → 可读性差

## ADR-003/004: 移除 research/ 目录和 session-catchup
- **日期**: 2026-02-15
- **状态**: accepted
- **决策**: 不单独建 research/ 目录（decisions.md 已承载决策推理）；不做 git diff 推断恢复（state.json 的 progress_log + next_action 已够用）
- **理由**: 减少文件分散和不准确推断，依赖已有机制

## ADR-006: consolidate-bash-into-core 收口约束
- **日期**: 2026-02-22
- **状态**: accepted
- **决策**:
  1. Full 模式 Phase 4/5 的 direct Write/Edit 在 require_dispatch=true 时由 guard 阻断，仅允许 execution agent 上下文写入。
  2. SessionStart 注入采用 SKILL section 裁剪（core/common + phase 相关段），缺少 section 时降级为全文注入。
  3. Findings 2-Action Rule 采用分级阈值：Discovery/Lite-L1=2，Phase 2/3=3，Execution/Review=4。
  4. 任务完成前必须具备可审计证据：gate/scenario 通过且 review 结果为 APPROVE。
- **理由**: 解决职责漂移、上下文膨胀与流程“口头完成”问题，确保完成声明有状态机与证据绑定。
- **替代方案**: 保持现状（仅依赖任务 status 和 marker 覆盖）→ 易出现“未 review 即完成”与伪覆盖通过。
