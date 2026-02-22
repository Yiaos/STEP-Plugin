## Code Review — independent-rereview-2026-02-22-final
**Files**: scripts/step-core.js, tests/test-scenario-status-sync.sh, tests/test-phase-gate-requirements.sh, .step/decisions.md | **Assessment**: REQUEST_CHANGES

### 第一轮：Spec Compliance（阻断）

#### Fresh Evidence（本轮复跑）
- `bash tests/test-scenario-status-sync.sh` => `2/2 passed, 0 failed`
- `bash tests/test-phase-gate-requirements.sh` => `7/7 passed, 0 failed`
- `bash tests/test-agent-enforcement.sh` => `5/5 passed, 0 failed`
- `node scripts/step-core.js scenario check --task dedup-task-status --change 2026-02-21-consolidate-bash-into-core` => `Coverage: 4/4 (100%)`
- `node scripts/step-core.js gate run --level lite --task dedup-task-status --mode incremental --config .step/config.json` => `✅ Gate PASSED`

#### P0 - Critical
1. `scenario-check` 仍可被“marker + 常量真命令”绕过，导致 ADR-006 的“可审计证据”不可信，阻断 APPROVE。
   - 证据：`scripts/step-core.js:537` 仍以 marker 命中作为场景通过条件；`scripts/step-core.js:420` 仅拦截 `assert "[S-x]" true|:|echo` 三类字面形式。
   - 复现实证（本轮）：在最小沙箱测试文件写入 `assert "[S-bypass-01]" /bin/true` 后，执行 `bash scripts/scenario-check.sh t1 c1` 输出 `Coverage: 1/1 (100%)` 且 `EXIT_CODE=0`。
   - 影响：`.step/decisions.md:39`（ADR-006 第 4 条）声明“任务完成前必须具备可审计证据（gate/scenario + review）”，但当前 scenario 证据可伪造，收口未完成。

### 第二轮：Code Quality
- 按两阶段规则，第一轮未通过，不进入第二轮。

### Suggested Improvements (v2 建议)
- 将场景通过条件绑定到“测试执行结果”而非静态 marker 命中（至少校验 test runner 输出中对应 `test_name` 的 PASS）。
- 对 shell 场景增加负例规则：拒绝 `assert "[S-xxx]" /bin/true`、`command true` 等恒真命令模式。
- 在 `scenario-check` 输出中区分“注释命中”“非断言命中”“恒真断言命中”，便于审计定位。
