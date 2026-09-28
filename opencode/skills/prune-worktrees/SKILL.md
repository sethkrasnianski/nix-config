---
name: prune-worktrees
description: Use when the user asks to prune, remove, delete, or clean up a GitHub project's local Git worktrees. Removes selected worktree checkouts only; preserves branches and pull requests.
---

# Prune Worktrees

Safely remove selected linked worktree checkouts from a GitHub project. This
skill removes worktree checkouts only: never delete local branches, remote
branches, or GitHub pull requests.

## Safety Rules

- Use OpenCode's built-in `question` tool for each required user decision. In
  the same turn, mirror the exact question and its options as plain chat text;
  some clients render the structured question UI unreliably. Wait for each
  answer before acting on it.
- Never use `rm`, `rmdir`, or another filesystem operation to delete a
  worktree. Remove checkouts only with `git worktree remove`.
- Never run `git worktree prune`, unlock a worktree, or use double force. Leave
  every locked worktree untouched.
- Never delete or prune branches, push branch deletions, or close pull
  requests. Do not run `git branch -d/-D`, `git push`, or `gh pr close`.
- A general confirmation to remove selected paths does not authorize forcing
  removal of dirty worktrees. Get separate, path-specific approval for each
  dirty worktree before using `--force` on it.
- Never evaluate `.worktrees` as shell code or split paths on whitespace.

## Workflow

### 1. Find the project and its worktree directory

Run `git rev-parse --show-toplevel` to confirm the current checkout belongs to
the intended project. Read `git worktree list --porcelain -z` and parse its
NUL-delimited records without shell word-splitting. Git lists the primary
checkout first. Use that checkout's root for `.worktrees` even if this session
was started inside a linked worktree.

Read `<primary-checkout>/.worktrees` as plain text:

- If it exists, require exactly one non-empty path on one line, with at most
  one optional trailing LF. Do not trim or reinterpret the path. Reject blank
  lines, multiple lines, CR characters, and non-file entries; do not overwrite
  or repair a malformed existing file. Explain the format issue and ask the
  user to correct it, then stop.
- If it is missing, ask the user for the directory containing this project's
  task worktrees. Use `question` with a free-text answer and mirror the
  question in plain chat. Accept an absolute path or a path relative to the
  primary checkout root. Do not expand shell variables or `~`. Resolve the
  path from the primary root when relative, and validate that it resolves to
  an existing directory. If invalid, explain why and ask again. Only after it
  validates, create `.worktrees` with that one path and a trailing newline;
  never overwrite a file that appeared in the meantime.
- Resolve the configured directory to its canonical absolute path. If it
  cannot be read or validated, stop without changing worktrees.

### 2. Find eligible worktrees

From the parsed `git worktree list --porcelain -z` records, exclude the first
(primary) checkout. Match only registered worktree paths that are strict
descendants of the configured directory, using canonical paths and a path
component boundary (not a simple string prefix). Do not include the directory
itself. Ignore missing or prunable checkout paths; report them as stale
registrations and leave them for a separate explicit cleanup.

Identify lock state from the porcelain records. Report matching locked paths,
but never offer them as deletable choices and never try to unlock or remove
them. If there are no matching worktrees, report that and stop. If all matches
are locked or unavailable, report that and stop.

Show the full absolute path and branch (or detached HEAD) for every eligible
worktree. Ask exactly one of:

- **Delete all worktrees** — select every eligible, unlocked match.
- **Select which worktrees to delete** — offer the complete eligible list with
  `question` and `multiple: true`.

For the multiple-choice question, use unique labels such as `Worktree 1` and
put each full path and branch in its description. Mirror the same numbered
list and both choices in plain chat. If the user cancels or selects none, stop.

### 3. Confirm the selected paths

Check each selected worktree with
`git -C <path> status --porcelain --untracked-files=all`. Treat any output as
dirty, including staged, unstaged, and untracked files. Do not include ignored
files in this check. Do not print file contents.

Show the exact selected absolute paths, their branches, and which are dirty.
Ask the user to confirm removal of this exact list. Make clear that this
confirmation does not authorize force-removal: each dirty worktree will need
its own approval. Mirror the confirmation in plain chat. If the user declines,
stop without removing anything.

For every selected dirty worktree, ask a separate yes/no question naming its
exact absolute path and stating that force-removal may discard its
uncommitted and untracked files. Mirror each question in plain chat, one
worktree at a time. Only an explicit approval for that path authorizes
`git worktree remove --force` for it. A refusal skips that worktree and does
not affect approvals for other paths.

### 4. Remove approved worktrees

Immediately before each removal, recheck that the path is still a registered
eligible worktree, remains under the configured directory, exists, and is not
locked. If any check fails, skip it and report why. Recheck its status too. If
it is dirty and has not received a separate approval for its current dirty
state, ask for that path-specific approval before proceeding.

- Remove a clean worktree with `git -C <primary-checkout> worktree remove
  <absolute-path>` (without force).
- Remove a dirty worktree only after its own explicit approval, using `git -C
  <primary-checkout> worktree remove --force <absolute-path>` (one force only).
- If Git refuses removal, report the error and stop for that path. Do not
  retry with more force or delete its directory directly.

Report removed paths, skipped paths and reasons, and failures. State that
branches and pull requests were left unchanged.
