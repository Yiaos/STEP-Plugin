---
description: "Initialize or resume the STEP protocol (Stateful Task Execution Protocol)."
---

Supported modes:
- `/step quick`: fast path for small changes (model decides fit; can escalate mid-flow)
- `/step lite`: lightweight task path
- `/step full`: full workflow path

Invoke `step:using-superpowers` first (STEP global guard skill), then route by phase:
- phase-0/1 -> `step:brainstorming`
- phase-2/3 -> `step:writing-plans`
- phase-4/5 -> `step:executing-plans`

Note: Quick mode does not use hard thresholds (file count/keywords). Suitability is decided semantically by the model.

Check whether STEP is initialized for the current project (`.step/` directory exists).

## If `.step/` does not exist (first-time init)

1. Set plugin root variable: `OPENCODE_PLUGIN_ROOT=${OPENCODE_PLUGIN_ROOT:-$HOME/.config/opencode/tools/step}`
2. Run `bash ${OPENCODE_PLUGIN_ROOT:-$HOME/.config/opencode/tools/step}/scripts/step-init.sh`
3. Set `state.json.current_phase` to `phase-0-discovery`
4. If output contains `[EXISTING PROJECT`:
   - Analyze existing code structure, framework, and conventions
   - Identify established patterns (naming, architecture, testing strategy)
   - Write context to `.step/baseline.md`
   - Set `state.json.established_patterns`
5. If this is a greenfield project, enter Phase 0 Discovery

## If `.step/` already exists (resume session)

1. Read `.step/state.json`
2. Read `.step/baseline.md`
3. If there is a current task, read the task Markdown (JSON code block)
4. Route based on `current_phase`
5. Output status line: `📍 Phase X | Change: {name} | Task: {slug} | Status: xxx | Next: xxx`
6. Continue from the recorded interruption point

## Worktree Auto Mode (optional)

If `.step/config.json` has:

```json
{
  "worktree": {
    "enabled": true
  }
}
```

Automatically create an isolated worktree at change start:

- Run `bash ${OPENCODE_PLUGIN_ROOT:-$HOME/.config/opencode/tools/step}/scripts/step-worktree.sh create {change-name}`
- Execute Phase 4 in that worktree (TDD + gate + review + commit inside worktree)
- After worktree commit, ask whether to merge; push only after merge+archive completes

## Preflight Health Check

Before entering STEP flow, run:

`bash ${OPENCODE_PLUGIN_ROOT:-$HOME/.config/opencode/tools/step}/scripts/step-manager.sh doctor`

Then enter state-machine execution mode (example):

`bash ${OPENCODE_PLUGIN_ROOT:-$HOME/.config/opencode/tools/step}/scripts/step-manager.sh enter --mode full --change init`

- If check result is PASS: continue into the target phase
- If check result is FAIL: stop immediately and run the script-provided remediation command first (for example `bash ${OPENCODE_PLUGIN_ROOT:-$HOME/.config/opencode/tools/step}/install.sh --force`)
- If not entered: PreToolUse auto-enters first (default `full`), then validates Write/Edit/Bash/Task by current phase; it does not allow implementation commands directly in `idle`

## Cross-Phase Rules

Load the `step` skill and follow it strictly.

- Phase 0 (Discovery): open discussion, user-led direction
- Phase 1 (PRD): staged baseline draft with structured confirmation
- Phase 2 (Tech Design): open technical option discussion
- Phase 3 (Planning): task graph and BDD scenario matrix
- Phase 4 (Execution): TDD + gate + review + commit/push (archive optional after completion)
- Phase 5 (Review): independent review (spec compliance > code quality)

At the end of each conversation, update `.step/state.json`. `next_action` must be specific to file and action.
