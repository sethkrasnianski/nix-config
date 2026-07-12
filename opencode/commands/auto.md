---
description: Run the full auto-agent pipeline (research, plan, PR gate, TDD implement, review, finalize) end-to-end for a goal.
agent: auto
subtask: false
---
Run the complete auto-agent pipeline end-to-end for the goal below. Follow your own agent instructions in full: run the repo-adaptation protocol and task research via `@auto-researcher`, get an explicitly approved TDD-shaped plan via `@auto-planner`, set up a dedicated worktree and branch per the `worktree-workflow` skill, offer the PR gate and rebase-watcher choice, then execute the TDD implementation loop step by step (delegating to `@auto-test-writer`, `@auto-implementer`, and — only on failure, never escalating model tier — `@auto-test-fixer`), run `@auto-reviewer`, route findings back through the loop, and finalize only through `@auto-history-finalizer` with one SHA-bound publish gate before reporting the final PR state.

If `.auto/research.md` or `.auto/plan.md` already exist in a matching in-progress worktree for this goal, treat this as resuming rather than starting over — re-read them first.

Goal:
$ARGUMENTS
