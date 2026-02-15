# Architecture Decision Log

## ADR-001: state.yaml 头部嵌入行为规则（F-1）
- **日期**: 2026-02-15
- **状态**: accepted
- **上下文**: PreToolUse hook 通过 `cat state.yaml | head` 注入状态到 LLM 上下文，但 LLM 看到纯数据后不知道该做什么（Gap #1）
- **决策**: 在 state.yaml 模板头部增加 4 行行为规则注释，head 从 20→25
- **理由**: planning-with-files 的 task_plan.md 混合规则+数据，LLM 遵循率更高。注释不影响 YAML 解析
- **替代方案**: 单独建 .step/rules.txt 让 hook 先 cat rules 再 cat state → 多一次 IO，hook 只能写一条 command
- **影响**: templates/state.yaml, skills/step/SKILL.md (head -20 → head -25)

## ADR-002: Stop hook 改为独立脚本（F-3）
- **日期**: 2026-02-15
- **状态**: accepted
- **上下文**: 当前 Stop hook 只是 echo 提醒，LLM 可以完全忽略（Gap #5）
- **决策**: 新建 scripts/step-stop-check.sh，检查 last_updated 和 progress_log，输出 pass/warn/fail
- **理由**: 与 gate.sh 对齐，从"软提醒"升级为"中等保证"；独立脚本可复用、可测试
- **替代方案**: 内联复杂 bash 到 SKILL.md frontmatter → 可读性差，难维护
- **影响**: 新文件 scripts/step-stop-check.sh, skills/step/SKILL.md Stop hook

## ADR-003: 移除 F-5 research/ 目录（简化）
- **日期**: 2026-02-15
- **状态**: accepted
- **上下文**: 原计划新建 .step/research/ 存调研过程，但 decisions.md 已有 ADR 格式含"替代方案"字段
- **决策**: 移除 F-5，详细决策依据写在 decisions.md 的 ADR 中
- **理由**: 减少文件分散，decisions.md 已能承载决策推理过程
- **替代方案**: 保留 research/ 目录 → 增加复杂度，与 decisions.md 职责重叠
- **影响**: baseline 从 9 项减为 7 项（后调整为 8 项→7 项）

## ADR-004: F-6 session-catchup 移除
- **日期**: 2026-02-15
- **状态**: accepted
- **上下文**: 原计划通过 git diff + 文件时间推断上次进度（Gap #3）
- **决策**: 移除，依赖 state.yaml 的 progress_log + next_action 做会话恢复
- **理由**: 用户判断 progress_log 已足够；session-catchup 脚本依赖 git 状态推断，可能不准确
- **替代方案**: 保留作为 P1
- **影响**: baseline 减少一项

## ADR-005: Baseline 语义从"冻结合同"改为"活快照"
- **日期**: 2026-02-15
- **状态**: accepted
- **上下文**: "冻结"暗示不可变，但文件系统无写保护（软保证），团队已多次违反（4→7角色未走CR）。冻结模型存在根本矛盾：以硬保证的语言描述软保证的现实
- **决策**: baseline 改为"活快照"——首版确认后仍受 CR 保护，但在任务完成+用户确认后可更新。CR 从"审批门禁"变为"审计记录"，decision 字段改为 recorded/reverted
- **理由**: 消除"冻结"与"无写保护"的矛盾；CR 作为审计记录更符合实际使用模式
- **替代方案**: 保持冻结语义 + 补回缺失的 CR → 会导致 CR 流程被忽略，因为不符合实际开发节奏
- **影响**: ~50 处文本变更覆盖 12 个文件（SKILL.md、WORKFLOW.md、README.md、agents/pm.md、templates/baseline.md、.step/baseline.md、scripts/step-init.sh、templates/cr.yaml、comparisons/*.md），零脚本/测试逻辑变更
