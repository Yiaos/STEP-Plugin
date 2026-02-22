---
name: executing-plans
description: Use when you have a written implementation plan to execute in a separate session with review checkpoints
---

# Executing Plans

## Overview

Load plan, review critically, execute tasks in batches, report for review between batches.

STEP overlay:
- Confirm current phase is `phase-4-execution` or `phase-5-review` before execution
- Run gate checks after each task batch and persist evidence
- Update `.step/state.json` (`progress_log`/`next_action`) when state changes

**Core principle:** Batch execution with checkpoints for architect review.

**Announce at start:** "I'm using the executing-plans skill to implement this plan."

## The Process

### Step 1: Load and Review Plan
1. Read plan file
2. Review critically - identify any questions or concerns about the plan
3. If concerns: Raise them with your human partner before starting
4. If no concerns: Create TodoWrite and proceed

### Step 2: Execute Batch
**Default: First 3 tasks**

For each task:
1. Mark as in_progress
2. Follow each step exactly (plan has bite-sized steps)
3. Run verifications as specified
4. Mark as completed
5. Run: `bash ${OPENCODE_PLUGIN_ROOT:-$HOME/.config/opencode/tools/step}/scripts/gate.sh lite <task-slug>`
6. Run: `bash ${OPENCODE_PLUGIN_ROOT:-$HOME/.config/opencode/tools/step}/scripts/scenario-check.sh <task-slug> [change-name]`

### Step 3: Report
When batch complete:
- Show what was implemented
- Show verification output
- Say: "Ready for feedback."
- Include key gate/scenario-check output to avoid evidence-free success claims

### Step 4: Continue
Based on feedback:
- Apply changes if needed
- Execute next batch
- Repeat until complete

### Step 5: Complete Development

After all tasks complete and verified:
- Announce: "I'm using the finishing-a-development-branch skill to complete this work."
- **REQUIRED SUB-SKILL:** Use step:finishing-a-development-branch
- Follow that skill to verify tests, present options, execute choice

## When to Stop and Ask for Help

**STOP executing immediately when:**
- Hit a blocker mid-batch (missing dependency, test fails, instruction unclear)
- Plan has critical gaps preventing starting
- You don't understand an instruction
- Verification fails repeatedly

**Ask for clarification rather than guessing.**

## When to Revisit Earlier Steps

**Return to Review (Step 1) when:**
- Partner updates the plan based on your feedback
- Fundamental approach needs rethinking

**Don't force through blockers** - stop and ask.

## Remember
- Review plan critically first
- Follow plan steps exactly
- Don't skip verifications
- Reference skills when plan says to
- Between batches: just report and wait
- Stop when blocked, don't guess
- Never start implementation on main/master branch without explicit user consent

## Integration

**Required workflow skills:**
- **step:using-git-worktrees** - REQUIRED: Set up isolated workspace before starting
- **step:writing-plans** - Creates the plan this skill executes
- **step:finishing-a-development-branch** - Complete development after all tasks

## STEP Evidence Reminder

- Gate evidence: `.step/changes/{change}/evidence/{task-slug}-gate.json`
- Review evidence: `.step/changes/{change}/evidence/{task-slug}-review.md`
- Move task status to done only after evidence and scenario coverage both pass
