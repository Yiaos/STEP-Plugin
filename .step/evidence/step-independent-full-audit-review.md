## Code Review — step-independent-full-audit
**Files**: scripts/commands/docs/skill/schema/hooks/agents/tests | **Assessment**: REQUEST_CHANGES

### Overall assessment
- 第一轮 Spec Compliance 不通过：存在 P0 级运行时与流程约束不一致（auto-enter quick 绕过 full 规划阶段写锁/委派约束），且文档与实现存在多处基线级不一致。

### Findings

#### P0 - Critical
- `hooks/hooks.json:9` 与 `skills/step/SKILL.md:9` 将 PreToolUse 固定为 `STEP_AUTO_ENTER_MODE=quick`，配合 `scripts/step-pretool-guard.sh:61` 自动 enter，会在 `idle` 时直接进入 `lite-l1-quick-spec`（非 full）。这与 `commands/step.md:65` 的“未 enter 阻断执行”语义冲突，并实际绕过 full 模式 phase-1/2/3 的写锁与委派强约束（见 `scripts/step-manager.sh:183`, `scripts/step-manager.sh:293`, `scripts/step-manager.sh:300`）。

#### P1 - High
- 基线文档仍以 YAML 术语定义核心约束，和仓库 JSON 实现不一致：` .step/baseline.md:34`, `.step/baseline.md:44`, `.step/baseline.md:71`, `.step/baseline.md:82`, `.step/baseline.md:84`，以及 `.step/decisions.md:12`, `.step/decisions.md:15`。这会直接影响约束判定（C-2/C-4）和审查口径。
- BDD 追踪链不完整：`tests/test-step-phase-enforcement.sh:35` 起新增 S-023-01..11，但当前任务规格仅声明 `S-stabilize-step-trigger-enforcement-*`（`.step/changes/2026-02-17-stabilize-step-reliability/tasks/stabilize-step-trigger-enforcement.md:21`）。缺少任务级场景来源，scenario-check 无法覆盖这组场景的“需求->测试”映射。

#### P2 - Medium
- Schema 与运行时校验不一致：`schemas/state.schema.json:12` 要求 `session` 必填，但 `scripts/step-core.js:94` 的 `validateState` 未校验 `session`；`schemas/config.schema.json:30` 定义 `enforcement`，但 `scripts/step-core.js:160` 的 `validateConfig` 未校验该段。结果是“schema 合法性”与“运行时 gate 合法性”口径分裂。

#### P3 - Low
- 无。

### Consistency checks passed
- `bash scripts/gate.sh lite findings-two-action-rule` 通过，含测试与 scenario 覆盖（最新输出见本次审查记录）。
- `bash scripts/scenario-check.sh findings-two-action-rule 2026-02-19-findings-two-action-rule` → `Coverage: 3/3 (100%)`。
- `bash scripts/scenario-check.sh stabilize-step-trigger-enforcement 2026-02-17-stabilize-step-reliability` → `Coverage: 4/4 (100%)`。
- `bash tests/test-step-phase-enforcement.sh` → `11/11 passed`。

### Residual risks
- 未在真实 opencode/Claude hook runtime 下做端到端交互复现（本次通过脚本沙箱复现了 auto-enter quick 行为）。
- 未审查 comparisons 文档的业务正确性，只做了与本次约束相关的一致性抽查。
- 未覆盖第三方环境差异（仅本地 darwin shell 验证）。
