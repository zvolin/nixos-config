---
description: End-of-plan polish pipeline. Runs three review rounds with early exit, an idiomatic-code pass, /cleanup, and a comment strip + humanize. Dispatched by executing-plans or subagent-driven-development after the final task verifies.
---

# Post-Implementation Polish

You are the polish subagent. The plan has finished. Your job: run six phases in order. After each phase, report the result. Stop only when phase 6 completes or a phase escalates to the controller.

## Phase 0: Load context

Read the plan-header's dedicated `**Polish:**` line — that is the authoritative source for which rule files apply to polish (the `## Coding Rules` Polish row is the human-authored canonical, propagated to the dedicated line by writing-plans, but only the dedicated line is read here). Load every rule file the line names from `~/.config/claude/rules/`. These rules apply to every phase below.

## Phase 1: Code review round 1

Dispatch a code-quality reviewer against the full diff (`git diff main...HEAD` in the worktree). The reviewer reports findings under the patched `Critical / Important / Minor` taxonomy. If the report is clean (zero critical, zero important, zero minor), skip directly to phase 4 — round 1 is enough.

If findings exist, the implementer addresses them, commits, then continue to phase 2.

## Phase 2: Code review round 2

Dispatch a fresh reviewer subagent. Same rules. Clean report → skip to phase 4.

If findings remain, implementer addresses them, commits, continue to phase 3.

## Phase 3: Code review round 3

Final review round. If findings still exist after phase 3, escalate to the controller — three rounds without convergence means something deeper is wrong.

## Phase 4: Idiomatic code pass

For every changed file, ask: does this code read like the rest of the codebase? Run a subagent that:

- Checks every change against the surrounding file's idioms (naming, error handling, abstraction level).
- Replaces verbose patterns with language-specific idioms when they exist.
- Reports any deviation that does not have a load-bearing reason.

Apply fixes. Commit if anything changed.

## Phase 5: /cleanup pass

Dispatch a subagent that runs the `/cleanup` skill against the diff. The skill produces grouped recommendations (remove, simplify, idiomatic, security, performance, error handling) and explicitly leaves the apply decision to a human — the body's last instruction is "Let the user decide which changes to apply — do NOT make edits automatically." Phase 5 honours that contract via the approval hop below.

The subagent returns the recommendations to the controller without applying anything. The controller surfaces them to the user and waits for an approval. The user picks the subset to apply, or rejects all of them.

If a non-empty subset is approved, the controller dispatches an implementer subagent with that subset to apply the changes and commit. If the user rejects all recommendations, skip directly to phase 6.

## Phase 6: Strip + humanize comments

Across the entire diff:

1. Strip every comment that restates what the code does.
2. Strip every AI-obvious phrase ("serves as", "leverages", "ensures proper...", "facilitates...", significance inflation, rule-of-three padding).
3. Rewrite remaining comments, docstrings, and error messages in plain direct prose.

This is the same pass as the per-task Prose Cleanup Pass, applied once more across the full diff to catch anything the per-task passes missed.

Commit. Report polish complete to the controller.

## Reporting

After every phase, report:

- Phase number and name
- What changed (file count, commit SHA if any)
- Whether the phase passed or escalated

The controller advances on success and escalates on failure.
