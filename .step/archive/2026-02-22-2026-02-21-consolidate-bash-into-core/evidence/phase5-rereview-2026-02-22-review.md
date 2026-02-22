## Code Review — phase5-rereview-2026-02-22
**Files**: 6 files, targeted regression scope | **Assessment**: REQUEST_CHANGES

### Spec Compliance (Phase 1)
- PASS: `tests/test-scenario-status-sync.sh` 三个场景均通过，quoting/变量展开修复已生效（`tests/test-scenario-status-sync.sh:4`, `tests/test-scenario-status-sync.sh:116`, `tests/test-scenario-status-sync.sh:117`, `tests/test-scenario-status-sync.sh:118`）。
- FAIL (P0): `scripts/step-core.js` 仍允许 `pass_case|fail_case` 行直接计入覆盖，未满足“必须可执行断言行”约束（`scripts/step-core.js:415`, `scripts/step-core.js:430`）。已复现实例：仅 `pass_case "[S-bypass-01] marker only"` 也被判定 100% 覆盖。
- PASS: gate/scenario/review 约束仍生效（`scripts/step-core.js:1295`, `scripts/step-core.js:1319`, `scripts/step-core.js:1331`, `scripts/step-core.js:1399`, `scripts/step-core.js:1415`；`tests/test-phase-gate-requirements.sh:262`）。
- PASS: 增量 gate 多段命令回退逻辑有效（`scripts/step-core.js:859`, `scripts/step-core.js:865`, `scripts/step-core.js:909`；`tests/test-gate-incremental.sh:108`）。

### P0 - Critical
- `scripts/step-core.js:415` 违反反作弊基线：`containsTokenInExecutableLine` 将 `pass_case|fail_case` 视为可验证覆盖，导致“仅 marker + 无断言”可绕过 coverage。该问题直接否定“必须可执行断言行”的需求。

### P1 - High
- none

### P2 - Medium
- none

### P3 - Low
- none

### Suggested Improvements (v2 建议)
- 将可计入覆盖的 shell 行严格收敛到 `assert` 且 `assert` 命令段非 trivial；`pass_case|fail_case` 仅作为测试框架输出，不参与覆盖判定。
- 新增反例测试：`pass_case "[S-xxx] marker only"` 必须触发 `scenario-check` FAIL。
