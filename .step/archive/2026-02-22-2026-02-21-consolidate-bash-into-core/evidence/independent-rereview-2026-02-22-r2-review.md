## Code Review — independent-rereview-2026-02-22-r2
**Files**: scripts/step-core.js, scripts/scenario-check.sh, tests/test-scenario-status-sync.sh, tests/test-phase-gate-requirements.sh, tests/test-agent-enforcement.sh, .step/decisions.md, .step/changes/2026-02-21-consolidate-bash-into-core/spec.md, .step/changes/2026-02-21-consolidate-bash-into-core/evidence/dedup-task-status-gate.json | **Assessment**: REQUEST_CHANGES

### 第一轮：Spec Compliance（阻断）

#### Fresh Evidence（本轮复跑）
- `bash tests/test-scenario-status-sync.sh` => `2/2 passed, 0 failed`
- `bash tests/test-phase-gate-requirements.sh` => `7/7 passed, 0 failed`
- `node scripts/step-core.js scenario check --task dedup-task-status --change 2026-02-21-consolidate-bash-into-core` => `Coverage: 4/4 (100%)`
- `node scripts/step-core.js gate run --level lite --task dedup-task-status --mode incremental --config .step/config.json` => `✅ Gate PASSED`

#### P0 - Critical
1. `scenario-check` 仍存在“marker 冒充断言”残余路径，阻断项未清零。
   - 证据：`scripts/step-core.js:415` 仅校验 shell 行包含 `assert|pass_case|fail_case` 关键字，不校验断言语义。
   - 证据：`tests/test-scenario-status-sync.sh:70` 使用 `assert "[S-task-status-sync-02]" true`，该模式不验证业务行为仍可通过。
   - 复现实证：临时沙箱中 `assert "[S-x-01]" true` + `scenario-check` 得到 `Coverage: 1/1 (100%)`（本轮复跑输出）。

### 第二轮：Code Quality
- 按两阶段规则，第一轮未通过，不进入第二轮。

### Suggested Improvements (v2 建议)
- 将 `scenario-check` 从静态 marker 检测升级为“测试执行结果绑定”：至少要求 `test_name` 可定位到测试用例并且用例执行成功后再回写 `scenario.status=pass`。
- 对 shell 的最小可信约束增加负例：拒绝 `assert "[S-xxx]" true` 这类常量真断言模式。
- 诊断文案修正：当前对非注释行失败也提示“only found in comment lines”（见 `scripts/step-core.js:535-537`），应区分“非断言语句命中”。
