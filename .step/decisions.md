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
