---
description: Implement an already-approved plan (.auto/plan.md) end to end — PR gate, TDD loop per step, review, and history finalize. Skips research/planning if already done.
agent: auto
subtask: false
---
`.auto/plan.md` should already exist and be approved (run `/plan` first if not). Starting from wherever this task currently stands:

1. If no worktree/branch exists yet for this task, set one up per the `worktree-workflow` skill.
2. If the PR gate hasn't been offered yet, offer it now (`Create Draft PR Now` / `Wait Until First Commit` / `Skip PR Creation`), then the rebase-watcher choice if a PR now exists.
3. Work through `.auto/plan.md` step by step via the TDD loop: `@auto-test-writer` → `@auto-implementer` → (only on failure, never escalating model tier) `@auto-test-fixer` → `@auto-committer`. Skip steps already committed in a prior run of this task.
4. Run `@auto-reviewer` once all steps are committed; route findings back through the loop.
5. Stop the watcher and finalize only via `@auto-history-finalizer`: prepare a local SHA-bound preview, ask once to publish that exact state, then publish through the trusted helper and mark the PR ready after verification.
6. Report final state: PR link, commit log, test/review status, watcher state, open questions.

Additional context, if any:
$ARGUMENTS
