---
name: atomic-commits
description: Use when creating, splitting, or rewriting commits inside the auto-agent harness — Conventional Commits format, staging discipline, fixup/autosquash mechanics, and the linear-history/force-with-lease rules that apply to every commit and rebase this harness performs.
metadata:
  audience: auto-committer, auto agents, address-pr-feedback, and resolve-merge-conflicts
  workflow: auto-agent
---

# Atomic Commits

This skill is the harness's single source of truth for commit conventions and history hygiene. Every agent that commits, amends, fixes up, or rebases defers to this skill instead of re-deriving its own commit style, so history is consistent regardless of which agent or model produced a given commit.

## Commit Message Format

Default convention: **[Conventional Commits](https://www.conventionalcommits.org/)**.

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

- `type` — one of: `feat`, `fix`, `chore`, `test`, `docs`, `refactor`, `perf`, `build`, `ci`, `style`, `revert`. Pick the most specific accurate type; do not default everything to `chore`.
- `description` — imperative mood ("add", not "added"/"adds"), lowercase start unless a proper noun, no trailing period, ≤72 characters total for the `type: description` line.
- `body` — only when it adds information the diff and subject don't already convey: *why*, not *what*. Wrap prose near 72 columns. Omit when the subject line is self-explanatory.
- `scope` — optional; use only when the repo already has an established scoping convention (e.g. `feat(auth): ...`) — don't invent scopes for a repo that doesn't use them.
- Breaking changes: `!` after type/scope (`feat!:`) and/or a `BREAKING CHANGE:` footer, per the spec, when applicable.

### Repo Override

Before the first commit in a given repo/worktree, check whether that repo has its own established convention (`git log --format='%s' -30` on its default branch). If the repo clearly uses something else consistently (a different tag style, ticket-ID prefixes, no prefixes at all), **follow the repo's convention instead** — this harness's Conventional Commits default is a fallback for repos with no strong existing convention, not a mandate to override one. Record which convention applies in `.auto/research.md` so every subagent in the session commits consistently. If genuinely mixed/inconsistent, default to Conventional Commits and note the inconsistency rather than guessing.

## Staging Discipline

- Never `git add -A`/`git add .` when a commit is meant to capture one logical change — stage precisely.
- Prefer `git add -p` (interactive hunk staging) or explicit `git add <path>` over broad adds, especially when the working tree has output from more than one step in flight.
- A commit produced by the `tdd-loop` skill bundles exactly: the test(s) for the behavior, and the implementation that makes them pass. Nothing from a different step, and no unrelated formatting/drive-by changes.
- If an editor or formatter touched unrelated lines as a side effect, either revert those hunks before staging or split them into their own `style:`/`chore:` commit — never let incidental formatting churn ride along inside a behavioral commit.

## One Commit Per Vertical Slice

Each commit should:

- Represent one coherent, independently reviewable change.
- Be bisectable: checking out that commit alone should leave the repo in a working state (tests pass) whenever practically achievable.
- Include its own tests and any docs describing the behavior it introduces — don't defer tests or docs to a "cleanup" commit later.
- Separate mechanical changes (renames, formatting, dependency bumps) from behavioral changes, even when they're related, unless splitting would be pure busywork with no reviewability benefit.

## Fixing Up Existing Commits

When a correction belongs to a commit already made earlier in this branch's history (a bug in your own earlier step, or feedback from `review-changes`/`address-pr-feedback`):

```bash
git add -p                      # stage only the relevant hunks
git commit --fixup=<sha>
```

Then, once all pending fixups for the current pass are staged:

```bash
GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash <merge-base>
```

`GIT_SEQUENCE_EDITOR=:` makes the rebase non-interactive (accepts the auto-generated fixup ordering without opening an editor) — use this form when the harness is driving the rebase programmatically; drop it if a human is actively steering the interactive rebase themselves.

Never edit an existing commit's message as a side effect of an autosquash fixup unless the business requirement or scope of that commit itself changed — and even then, only with explicit user confirmation (this mirrors `address-pr-feedback`'s rule; that skill is the canonical reference for the full commit-mapping workflow when the trigger is reviewer feedback specifically).

## Rebase And History Rules (Linear History)

This harness never merges. History stays linear via rebase, always. This has several concrete consequences:

- **Only rewrite commits unique to the current branch.** Never rebase, amend, or reorder a commit that is also reachable from the base/default branch. Determine the boundary with `git merge-base <base> HEAD` before any interactive rebase, and scope the rebase to `<merge-base>..HEAD`.
- **Rebase onto the latest base before finalizing**, so the merged result will fast-forward or apply cleanly: `git fetch origin && git rebase origin/<base>`.
- **Bootstrap commits are dropped, not left in.** If the branch started with an empty `chore: bootstrap <branch>` commit (see `worktree-workflow` skill) to open a draft PR before real work existed, drop it during the final history rewrite with `--no-keep-empty`:
  ```bash
  GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash --no-keep-empty <merge-base>
  ```
- **Conflicts during any of the above are handled by the `resolve-merge-conflicts` skill**, not improvised inline — that skill's non-negotiable rules (never blindly pick one side, never silently continue/abort) apply in full here.
- **History publication is helper-only.** `auto-history-finalizer` invokes
  `auto-history-finalize publish` with an explicit remote/refspec/SHA lease.
  A bare `--force` is never acceptable, and ordinary agents must not retry a
  stale lease with raw Git.
- **Never touch another branch's history.** All rebasing, amending, and fixup operations apply exclusively to the branch currently being worked (see `worktree-workflow` skill for how each task gets its own worktree + branch), never to `main`/`master`/the base branch, and never to a sibling task's branch.

## Verifying History Before Pushing

Before any push that follows a history rewrite, re-check:

```bash
git log --oneline <merge-base>..HEAD
```

Confirm:

- No leftover `fixup!`/`squash!`/WIP commit messages remain.
- No bootstrap/empty commit remains (unless intentionally kept — should be rare).
- Commit order reads as a coherent implementation story (tests+impl per step, in plan order).
- No commit message changed except ones explicitly approved by the user.
- Every commit's tests would plausibly pass in isolation (bisectability) — spot-check with the repo's test command on a sample commit if there's any doubt.

## Important Constraints

- Never use a commit type/format other than Conventional Commits unless the target repo has its own clearly established convention (see "Repo Override").
- Never bundle unrelated changes (different plan steps, formatting-only churn, opportunistic refactors) into one commit.
- Never rewrite a commit that is also reachable from the base branch.
- Never bare `git push --force` — always `--force-with-lease`.
- Never reword an existing commit's message as a fixup side effect without explicit user confirmation that the commit's actual scope changed.
- Never leave `fixup!`/`squash!`/WIP commits in history presented as "done."
