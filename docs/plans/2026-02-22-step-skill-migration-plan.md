# STEP Skill Migration Plan (Superpowers-based)

## Goal
Rebuild STEP skills using the `superpowers` skill structure as the template while preserving STEP script-level hard constraints (`state` / `gate` / `scenario` / `evidence`).

## Strategy
- Rewrite directly in `skills/step/` without a compatibility layer.
- Migrate global guard + core chains first, then command entrypoints, then run regression.

## Target Skill Set
- `using-superpowers` -> STEP global guard (may later rename to `using-step`)
- `brainstorming` -> STEP Phase 0/1 (Discovery + PRD)
- `writing-plans` -> STEP Phase 2/3 (Tech Design + Plan & Tasks)
- `executing-plans` -> STEP Phase 4/5 (Execution + Review + Gate)
- `verification-before-completion` -> STEP completion evidence verification
- `using-git-worktrees` + `finishing-a-development-branch` -> STEP worktree/finalize/archive flow

## Mapping (Superpowers -> STEP)
| Superpowers Skill | STEP Role |
|---|---|
| using-superpowers | Global guard: skill check before any action |
| brainstorming | Discovery/PRD constraints |
| writing-plans | Design/planning task breakdown + scenario matrix |
| executing-plans | Execution + gates (TDD/gate/scenario) |
| test-driven-development | Embedded as mandatory execution sub-flow |
| requesting-code-review / receiving-code-review | Phase 5 two-stage review integration |
| verification-before-completion | Pre-commit evidence and state consistency checks |
| using-git-worktrees | Optional worktree flow |
| finishing-a-development-branch | Post-completion commit/push/archive/finalize |

## Execution Rhythm
1. **Phase A**: Migrate global guard skill (gating, priority, trigger rules)
2. **Phase B**: Migrate 3 core chain skills (`brainstorming` / `writing-plans` / `executing-plans`)
3. **Phase C**: Migrate command entrypoints (`commands/step.md`, `commands/status.md`, `commands/archive.md`)
4. **Phase D**: Run core regression + full `gate.test`

## Done Criteria
- Skill docs no longer use the `superpowers:` prefix; all references use STEP semantics and commands.
- Core chain covers STEP Phase 0-5.
- Command entrypoints focus on skill orchestration instead of embedding heavy flow logic.
- `bash -lc "$(node -e 'const fs=require("fs");const c=JSON.parse(fs.readFileSync(".step/config.json","utf8"));process.stdout.write(c.gate.test)')"` passes fully.
