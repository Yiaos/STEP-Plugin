## Code Review — final-rereview-2026-02-22
**Files**: scripts/step-core.js, tests/test-scenario-status-sync.sh, .step/changes/2026-02-21-consolidate-bash-into-core/evidence/dedup-task-status-gate.json | **Assessment**: APPROVE

### 第一轮：Spec Compliance（通过）

#### Fresh Evidence（本轮复跑）
- `bash tests/test-scenario-status-sync.sh` => `4/4 passed, 0 failed`
- `node scripts/step-core.js scenario check --task dedup-task-status --change 2026-02-21-consolidate-bash-into-core` => `Coverage: 4/4 (100%)`
- `node scripts/step-core.js gate run --level lite --task dedup-task-status --mode incremental --config .step/config.json` => `✅ Gate PASSED`

#### 逐条结论
1. Baseline Constraints：未见违反 C-1~C-5。
2. Scope / Non-Goal：变更聚焦 scenario 可验证性收口，未越界新增功能。
3. BDD 场景覆盖：`S-task-status-sync-01..04` 均有执行且通过，新增 `S-task-status-sync-04` 明确覆盖 `pass_case marker-only` 负例。
4. ADR 一致性：与 `ADR-006` 的“完成声明必须绑定可审计证据”一致。
5. 测试可信度：`scripts/step-core.js` 现仅认可 shell 中 `assert` 且排除 trivial 命令（`true/:/echo//bin/true`），前轮 P0 的 marker 冒充路径已封堵。

### 第二轮：Code Quality

### P0 - Critical
- none

### P1 - High
- none

### P2 - Medium
- none

### P3 - Low
- none

### Suggested Improvements (v2 建议)
- 后续可把 shell 覆盖判定从“静态 assert 语句”进一步升级为“测试执行结果绑定 test_name + pass 状态”，彻底消除语义歧义。

### 覆盖范围与残留风险
- 已检查范围：`scripts/step-core.js` 场景匹配核心逻辑（`containsTokenInExecutableLine` 与 `checkScenarioCoverage`），`tests/test-scenario-status-sync.sh` 四个场景，及本轮 gate/scenario 输出。
- 未覆盖区域：非 shell 测试文件中的 marker 可信度策略（例如 JS/TS 测试语义校验）未在本轮扩展验证。
- 残留风险：当前仍属于静态文本规则，极端情况下可构造“非业务断言但非 trivial”语句通过覆盖；风险级别 P3。
