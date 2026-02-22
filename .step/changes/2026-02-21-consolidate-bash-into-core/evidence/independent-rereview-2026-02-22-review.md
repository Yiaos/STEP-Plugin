## Code Review — independent-rereview-2026-02-22
**Files**: scripts/step-core.js, hooks/session-start.sh, tests/test-session-start-hook.sh, tests/test-workflow-split.sh, tests/test-step-phase-enforcement.sh, tests/test-cancel-mechanism.sh, tests/test-findings-two-action-rule.sh, tests/test-e2e-rule-consistency.sh, tests/test-phase-gate-requirements.sh, tests/test-scenario-status-sync.sh, .step/decisions.md, .step/changes/2026-02-21-consolidate-bash-into-core/spec.md | **Assessment**: REQUEST_CHANGES

### 第一轮：Spec Compliance（阻断）

#### Fresh Evidence（本轮复跑）
- `bash tests/test-session-start-hook.sh && bash tests/test-workflow-split.sh && bash tests/test-step-phase-enforcement.sh && bash tests/test-cancel-mechanism.sh && bash tests/test-findings-two-action-rule.sh && bash tests/test-e2e-rule-consistency.sh && bash tests/test-phase-gate-requirements.sh` 全部 PASS。
- `node scripts/step-core.js scenario check --task session-start-fix --change 2026-02-21-consolidate-bash-into-core` 输出 `Coverage: 5/5 (100%)`。
- `node scripts/step-core.js gate run --level lite --task session-start-fix --mode incremental --config .step/config.json` 输出 `✅ Gate PASSED`，并写入证据文件。

#### P0 - Critical
1. `scenario-check` 仍可被“marker 冒充断言”绕过，问题未根治。
   - 证据：`scripts/step-core.js:521` 到 `scripts/step-core.js:523` 仍以 marker 字符串命中作为 PASS 条件（非断言语义验证）。
   - 证据：`tests/test-scenario-status-sync.sh:29` 到 `tests/test-scenario-status-sync.sh:32` 仅通过 `echo "[S-task-status-sync-01]"` 即可驱动场景通过。
   - 证据：`tests/test-scenario-status-sync.sh:64` 直接执行 `scenario-check` 后 `task ready` 可通过（`tests/test-scenario-status-sync.sh:65`）。

### 第二轮：Code Quality
- 按两阶段规则，第一轮未通过，不进入第二轮。

### Suggested Improvements (v2)
- 将覆盖判定从“字符串命中”升级为“测试结果绑定”：要求 `test_name` 对应测试实际执行且 PASS，再回写 `scenario.status`。
- 在 `scenario-check` 增加最小可信约束（至少校验 marker 所在行为语句类型，拒绝纯输出语句充当断言）。
