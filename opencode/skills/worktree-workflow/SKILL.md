---
name: worktree-workflow
description: Use when starting, resuming, or finalizing an auto-agent task — setting up an isolated git worktree and branch, opening a draft PR whose body carries the plan, running the background rebase watcher, and finalizing linear history before marking the PR ready. Central lifecycle skill for the auto-agent pipeline.
metadata:
  audience: auto agents (orchestrator, planner, committer)
  workflow: auto-agent
---

# Worktree Workflow

This skill defines how every `auto-agent` task isolates its work, carries its plan, and finalizes its history — independent of which target repo it runs against. It is what makes the harness portable: nothing here assumes a specific language, test framework, or repo layout, only that the target is a git repository with an `origin` remote.

## Core Principles

- Every task gets its own worktree and branch. The user's main checkout of the target repo is never touched.
- The PR description is the plan artifact — not a committed file in the branch. This is deliberate: the PR body survives every rebase untouched, while a committed plan doc would need to be surgically dropped later. Treat the PR body as durable, re-hydratable context (a `/compact` for the task) that any fresh session, the PR watcher, or a crash-recovered session can read back with `gh pr view --json body`.
- Scratch state (research notes, plan draft, logs) lives worktree-local and is never committed — see "Repo-Local Scratch State" below for exactly how, since this differs by whether the harness has permission to touch the repo's own `.gitignore`.
- Bootstrap the PR from an empty commit; drop that empty commit during final history rewrite. Working history should contain only real, bisectable commits by the time the PR is marked ready.
- History is linear, always — see `atomic-commits` skill for the full rebase/force-push rules. This skill covers the lifecycle around them (when to rebase, when to open the PR, when to run the watcher); `atomic-commits` covers the mechanics of the rebase itself.
- Nothing in this skill is repo-specific. Base branch, test commands, and conventions are discovered per-repo (see the repo-adaptation protocol in `auto.md`), not assumed.

## Required Workflow

### 1. Determine The Target Repo And Base Branch

```bash
git rev-parse --show-toplevel
gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'
git symbolic-ref refs/remotes/origin/HEAD --short
git fetch origin
```

If `gh repo view` is unavailable (no `gh` auth, or not a GitHub remote), fall back to the local symbolic-ref, and ask the user to confirm the base branch if both are inconclusive.

### 2. Create The Worktree And Branch

Derive a short slug from the task goal (kebab-case, no ticket-system assumptions unless one is configured). Branch type prefix (`feat/`, `fix/`, `chore/`, etc.) should match the dominant Conventional Commits type the task will produce (see `atomic-commits` skill).

```bash
git worktree add ../<repo-name>-worktrees/<type>-<slug> -b <type>/<slug> origin/<base>
```

- `<repo-name>-worktrees/` is a sibling directory to the target repo's own checkout, never inside it — this keeps the worktree fully outside the tree the user's main checkout is watching (IDEs, file watchers, etc.).
- Branch off `origin/<base>`, freshly fetched, not the local (possibly stale) base branch.
- All subsequent work — research, planning, implementation, commits — happens inside this worktree. Do not `cd` back to the user's main checkout to make changes.

If a worktree for this exact branch/slug already exists (resuming a task), reuse it — do not create a duplicate or delete-and-recreate without asking, since it may hold in-progress uncommitted state.

### 3. Repo-Local Scratch State

Research notes, the draft plan, and any logs the harness produces during the task must never be committed, and must not require the target repo to have its own compatible `.gitignore` entry (many repos won't; portability requires zero committed footprint).

Use the repo's own local exclude file, which is per-repo, never committed, and shared across all worktrees of that repo:

```bash
grep -qxF '.auto/' "$(git rev-parse --git-common-dir)/info/exclude" || \
  echo '.auto/' >> "$(git rev-parse --git-common-dir)/info/exclude"
```

`git rev-parse --git-common-dir` resolves to the shared `.git` directory even from inside a linked worktree, so this only needs to run once per repo (idempotent check-then-append above makes re-running safe). Do not add `.auto/` to the repo's tracked `.gitignore` — that would be a committed footprint in someone else's repo for harness-internal bookkeeping.

Scratch layout, created inside the worktree:

```
.auto/
├── research.md      # findings from auto-researcher: repo conventions, test/lint/build commands,
│                     #   discovered commit style, relevant existing code/patterns
├── plan.md           # the approved plan; source text for the PR body (see step 5)
├── pr-watch.log       # background rebase-watcher log, if the watcher is running
└── NEEDS_REBASE       # marker file the watcher drops on unresolvable conflict (see script)
```

### 4. Research And Plan (Interactive)

Research and planning phases are interactive by design — see `auto-researcher.md` and `auto-planner.md` for their specific model/reasoning configuration. Both write to `.auto/` as they go, and both should ask clarifying questions via the `question` tool, always mirrored in plain text, rather than guessing on ambiguous requirements.

The plan (`.auto/plan.md`) should be structured as an ordered list of TDD-shaped steps: each step names the behavior, the test(s) to write first, and the implementation it requires (see `tdd-loop` skill for the per-step protocol). End planning with an explicit approval question to the user before moving on.

### 5. The PR Gate (Before Any Implementation)

Once the plan is approved and *before* any test or implementation code is written, ask the user (recommended options shown) whether to open the PR now:

- `Create Draft PR Now` (recommended when the user wants live progress visibility / auto-rebase): bootstrap and open as below.
- `Wait Until First Commit`: skip this step for now; re-offer it after the first real commit lands.
- `Skip PR Creation`: user will open it manually later; harness continues working locally only.

If creating now:

```bash
git commit --allow-empty -m "chore: bootstrap <type>/<slug>"
git push -u origin <type>/<slug>
gh pr create --draft --base <base> --head <type>/<slug> \
  --title "<conventional-commit-style title>" \
  --body-file .auto/plan.md
```

The empty bootstrap commit exists solely to give the branch something to push before real work exists; it is dropped during final history rewrite (step 8) via `--no-keep-empty`. The PR body is generated from `.auto/plan.md` — if the plan evolves materially during implementation, update the PR body (`gh pr edit --body-file`) to keep the durable artifact current rather than letting it drift stale.

### 6. Offer The Background Rebase Watcher

Only relevant if a PR now exists (step 5). Ask:

- `Start Auto-Rebase Watcher` (recommended for longer-running tasks or when main is expected to move): spawns the background watcher.
- `Skip Watcher`: rebase manually/on-demand instead.

To start:

```bash
auto-pr-watch start <type>/<slug>
```

See `scripts/pr-watch.sh` (installed to `auto-pr-watch` on `PATH`) for exact mechanics: it periodically fetches, rebases the branch onto the updated base when behind, force-with-lease pushes on success, and on unresolvable conflict aborts the rebase, drops `.auto/NEEDS_REBASE`, comments on the PR, and stops — it never resolves conflicts itself (that's `resolve-merge-conflicts`'s job, invoked interactively afterward). Check watcher status any time with `auto-pr-watch status <type>/<slug>`, and stop it with `auto-pr-watch stop <type>/<slug>` (always stop it before the branch merges/closes if it's somehow still running — though the watcher also self-exits once it detects the PR is merged or closed).

### 7. Implement (TDD Loop Per Step)

Work the approved plan step by step per the `tdd-loop` skill, committing each green cycle per the `atomic-commits` skill. If a step's fix-attempt limit is exhausted, return `plan-delta` to the orchestrator for one targeted research and plan-adjustment cycle rather than skipping silently or asking the user directly.

After implementation, run the `review-changes` skill (read-only mode) against the branch. Route findings back through the TDD loop like any other planned change — write/adjust a failing test for the finding where applicable, then fix, then commit — rather than hand-patching outside the loop.

### 8. Finalize Linear History

Stop the watcher, then only `auto-history-finalizer` may invoke the trusted
helper. It creates a recovery ref, verifies the branch/upstream/remote lease,
rewrites locally, and runs the exact suite:

```bash
auto-history-finalize prepare --base <base> --test '<exact test command>'
```

Present the resulting base SHA, old/new head, commit log, expected remote SHA,
and test result. Ask exactly once to publish that precise state. On approval:

```bash
auto-history-finalize publish --base <base> --head <new-head> --remote <remote-sha>
```

Any changed head, base, test result, or remote SHA invalidates approval. Mark
the PR ready only after the helper verifies the remote.

### 9. Report Final State

Summarize: branch/PR link, final `git log --oneline` of the branch's unique commits, test/review status, whether the watcher is stopped, and any open questions or pushback items left for the user.

## Repo-Adaptation Note

This skill never assumes test commands, lint commands, commit conventions, or directory layout — those are discovered fresh per target repo (see the repo-adaptation protocol in `auto.md` and `auto-researcher.md`) and recorded in `.auto/research.md` for the rest of the session to reuse. A repo may also carry its own `.opencode/opencode.jsonc` overrides for agent models/prompts (see `commands/auto-init.md`) — those are config-level overrides and orthogonal to this skill's lifecycle mechanics.

## Important Constraints

- Never do task work in the user's main checkout — always in the dedicated worktree.
- Never commit `.auto/` scratch state; use the repo-local `info/exclude`, never the tracked `.gitignore`.
- Never write implementation code before the PR gate (step 5) has been offered, even if the user ultimately skips PR creation.
- Never leave the bootstrap empty commit in the final history — drop it with `--no-keep-empty` at finalize time.
- Never run the finalize rebase (step 8) while the PR watcher is still actively rebasing the same branch — stop it first.
- Never mark a PR ready with unresolved conflict markers, a failing test suite, or leftover `fixup!`/WIP commits.
- Never merge — this harness only ever rebases; see `atomic-commits` for the full linear-history rules.
