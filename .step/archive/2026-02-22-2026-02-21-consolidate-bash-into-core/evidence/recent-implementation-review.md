## Code Review — recent-implementation
**Files**: 22 files, ~2144 lines (git diff --stat) | **Assessment**: REQUEST_CHANGES

### Phase 1 — Spec Compliance（阻断）

#### Gate / Scenario Evidence (fresh)
- `bash scripts/gate.sh full agent-enforcement-enhance --all` 结果：`scenario-coverage: FAIL`，并写入 `.step/changes/2026-02-21-consolidate-bash-into-core/evidence/agent-enforcement-enhance-gate.json`
- `bash scripts/scenario-check.sh <task> 2026-02-21-consolidate-bash-into-core` 全量检查结果：10/10 任务未达 100% 覆盖（最低 0%）

#### P0 - Critical (需求不合规 / 安全 / 数据丢失)
1. BDD 场景覆盖硬性要求未满足（阻断）
   - 证据：`tests/test-agent-enforcement.sh` 仅覆盖 `S-agent-enforce-01/03/04`，缺失 `S-agent-enforce-02/05`（见 `.step/changes/2026-02-21-consolidate-bash-into-core/tasks/agent-enforcement-enhance.md`）
   - 证据：`tests/test-session-start-hook.sh` 仍为旧场景 `S-009-*`，未覆盖 `S-session-start-fix-*` 与 `S-phased-injection-*`
   - 证据：`tests/test-workflow-split.sh` 仅覆盖 `S-split-workflow-doc-01/03`，缺失 `S-split-workflow-doc-02/04`

2. `split-workflow-doc` 名义完成但 AC 不达标
   - 约束：任务要求 `WORKFLOW.md 行数 < 800`（`.step/changes/2026-02-21-consolidate-bash-into-core/tasks/split-workflow-doc.md`）
   - 实际：`WORKFLOW.md` 为 1511 行（`wc -l WORKFLOW.md`）
   - 结论：目标“从 1507 拆到 ~700”未实现

3. ADR 一致性缺失
   - 证据：`.step/decisions.md` 仅有 ADR-001/002/003/004/005（无本次变更 ADR）
   - 证据：`.step/changes/2026-02-21-consolidate-bash-into-core/spec.md` 第 57-59 行仍为 `decision: pending`
   - 影响：实现与决策日志不同步，违反 Review Phase 1 的 ADR 一致性检查

### Phase 2 — Code Quality（未进入）
- 按协议，Phase 1 未通过，停止进入代码质量审查。

### Suggested Improvements (v2 建议)
- 先补齐 10 个任务的缺失 scenario ID 测试，再重跑 `scenario-check.sh` 全量至 100%。
- 将 `split-workflow-doc` 的 AC 落实到可执行断言（行数、信息不丢失、内容完整性）并写入测试。
- 补充本次变更 ADR（至少覆盖：dispatch enforcement、session-start 注入裁剪、2-Action 阈值策略）。

### Handoff Checklist (可选)
- [ ] 所有任务 `scenario-check.sh` 100% 通过
- [ ] Gate full --all 通过且 `scenario-coverage: PASS`
- [ ] decisions.md 完成 ADR 同步
