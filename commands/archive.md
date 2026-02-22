---
description: "Archive completed STEP changes by moving completed folders from .step/changes/ to .step/archive/."
---

Archive completed STEP changes.

Before running archive, call `step:finishing-a-development-branch` for wrap-up checks.

## Usage

- `/archive` - interactive: list all completed changes, then archive after confirmation
- `/archive {change-name}` - archive a specific change (for example `/archive init` or `/archive 2026-02-20-add-dark-mode`)

## Execution Logic

1. Inspect all change folders under `.step/changes/`
2. For each change, verify every task under `tasks/` is `status: done`
3. Archive fully completed changes:
   - Move the whole change folder to `.step/archive/YYYY-MM-DD-{change-name}/`
   - Update baseline.md to reflect latest status
4. Report archive results

## After Archive

- Update `.step/state.json`: clear `current_change` (if archived change is the current one)
- Update `.step/baseline.md`: baseline reflects latest completed state
- Report: "Archived change {name} to .step/archive/"
