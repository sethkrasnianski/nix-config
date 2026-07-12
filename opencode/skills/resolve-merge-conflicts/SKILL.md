---
name: resolve-merge-conflicts
description: Use when resolving Git merge conflicts during an already-started merge, rebase, cherry-pick, revert, or stash apply; especially when the user says conflicts, rebase conflicts, merge markers, or resolve conflicts.
metadata:
---

# Resolve Merge Conflicts

Use this skill to resolve existing Git conflict markers safely. Assume the user is already in the conflicted operation, often an in-progress rebase. Do not initiate, advance, skip, abort, or otherwise control that operation unless the user explicitly instructs you to do that exact action.

This harness (see `worktree-workflow` skill) never merges branches — history stays linear via rebase only. In practice that means the conflicted operation you're called into is almost always a **rebase** (interactive autosquash, or a rebase onto an updated base), not a merge. This matters for reading conflict markers correctly: see the note under "Understand Both Sides" below.

## Non-Negotiable Rules

- Never start a new rebase, merge, cherry-pick, revert, pull, or stash operation.
- Never run `git rebase --continue`, `git rebase --abort`, `git rebase --skip`, `git merge --continue`, `git merge --abort`, `git cherry-pick --continue`, `git cherry-pick --abort`, `git cherry-pick --skip`, `git revert --continue`, `git revert --abort`, or equivalent commands unless the user explicitly asks for that exact command.
- Never use destructive reset or checkout commands to discard work unless the user explicitly asks for the exact discard behavior.
- Never resolve by blindly choosing one side for every conflict.
- Never leave conflict markers in tracked files.
- Never stage files unless the user explicitly asks you to stage them.
- Preserve unrelated user changes. Only edit files required to resolve the current conflicts.
- Ask the user before resolving conflicts that contain competing business logic, product behavior, data model semantics, security behavior, user-visible copy with different intent, or any behavior whose intended final result cannot be confidently inferred.

## User Interaction Tools

Use the available user-question tool whenever the workflow says to ask the user.

- In OpenCode, use `question`. Because some clients render the structured question UI unreliably, **always also mirror the same question, its options, and your recommended option as plain chat text** in the same turn — never rely on the structured UI alone to carry the question.
- In Claude Code, use `askuserquestion` or the equivalent available ask-user tool.
- In Codex, use the available ask-user tool if present; otherwise ask directly in chat and wait for the answer.
- If no structured question tool is available, ask directly in chat and wait for the answer before editing that conflict.

Ask concise questions with concrete options when possible. Include enough surrounding context for the user to understand the choice without reading the whole file.

## Required Workflow

### 1. Confirm Conflict State

Inspect the repository state before editing.

Use read-only Git commands such as:

```bash
git status --short
git status
git diff --name-only --diff-filter=U
```

If needed, inspect rebase or merge metadata read-only, for example:

```bash
git branch --show-current
git rev-parse --show-toplevel
```

Do not assume branch names, base branches, or intended behavior from memory.

### 2. Identify Conflicted Files

Find files with unresolved conflict markers or unmerged Git status.

Preferred checks:

```bash
git diff --name-only --diff-filter=U
git diff --check
```

Also search for textual markers before finishing:

```bash
rg '^(<<<<<<<|=======|>>>>>>>)'
```

If generated files, lockfiles, migrations, snapshots, or vendored artifacts are conflicted, inspect project instructions before editing. If the correct regeneration command is clear and safe, use it only after resolving source conflicts. If regeneration could advance the rebase or discard work, ask first.

### 3. Understand Both Sides

For each conflicted file:

- Read the whole conflicted region and enough surrounding code to understand the intent.
- Compare both sides semantically, not just line-by-line.
- Inspect nearby tests, types, schemas, docs, call sites, or migration history when they clarify the intended resolution.
- Prefer the smallest resolution that preserves both compatible changes.
- Keep formatting consistent with the file and project.

Remember that during rebase conflict markers, labels such as `HEAD`, `ours`, `theirs`, current branch, and rebased commit can be confusing. Do not rely on side labels alone to infer which change belongs to whom; inspect the actual code and commit context when available.

**During a rebase specifically (the common case in this harness), `HEAD`/`ours` refers to the commit already replayed onto the new base — usually the base branch's code — while `theirs` refers to the branch's own commit being replayed on top.** This is the inverse of what `ours`/`theirs` mean during a merge. If there's any doubt which operation is in progress, check for `.git/rebase-merge` or `.git/rebase-apply` (rebase in progress) versus `.git/MERGE_HEAD` (merge in progress) before relying on either label.

### 4. Ask Before Ambiguous Business Logic

Ask the user before editing a conflict when:

- Both sides intentionally implement different business behavior.
- Both sides change validation, authorization, billing, persistence, migrations, feature flags, external API contracts, or product workflow semantics.
- One side deletes code and the other side modifies it, and the deletion intent is unclear.
- Tests or documentation disagree with code behavior.
- The safe final behavior depends on product or domain knowledge not present in the repository.
- You cannot confidently explain why the chosen result is correct.

Good question shape:

```markdown
`path/to/file.ts` has a conflict in `functionName`:

- Option A: keep behavior X from the rebased side.
- Option B: keep behavior Y from the incoming commit.
- Option C: combine them as Z.

Which behavior should be final?
```

Continue resolving independent, non-ambiguous conflicts while waiting only if doing so will not depend on the user's answer.

### 5. Edit Safely

When the intended resolution is clear:

- Remove all conflict markers from the file.
- Preserve imports, exports, types, schemas, route contracts, and tests consistently.
- If both sides added different names for the same concept, prefer the name already established in the target codebase unless project instructions say otherwise.
- If both sides added tests, keep or combine coverage rather than deleting one side by default.
- If a file was renamed or moved on one side, verify the final path and references before editing.
- If package or lock files conflict, resolve manifest intent first, then update the lockfile using the repository's package manager if that is the established workflow.

Use the environment's normal file-editing tool. Avoid broad scripted edits unless the conflict pattern is simple, repeated, and verified.

### 6. Verify Resolution

After editing conflicts, run the narrowest safe checks available.

Minimum checks:

```bash
git diff --check
rg '^(<<<<<<<|=======|>>>>>>>)'
git diff --name-only --diff-filter=U
```

Then run targeted project checks when practical, such as type checks, lint, unit tests, or the specific tests related to the conflicted files. Do not run commands that continue, skip, abort, or restart the in-progress Git operation.

If verification fails, fix the issue when it is clearly caused by the conflict resolution. If the failure indicates ambiguous desired behavior, ask the user.

### 7. Report Final State

Finish with a concise summary:

- Files resolved.
- Any user decisions applied.
- Verification commands run and results.
- Remaining conflicts or blockers, if any.
- Whether files are unstaged or staged.
- Reminder that the rebase or merge has not been continued unless the user explicitly asked for that.

Do not tell the user you completed the rebase unless you actually ran the explicit continue command at their request.

## Safe Command Reference

Usually safe, read-only commands:

```bash
git status
git status --short
git diff
git diff --check
git diff --name-only --diff-filter=U
git log --oneline --decorate -20
git show --stat
git rev-parse --show-toplevel
git branch --show-current
```

Commands requiring explicit user instruction:

```bash
git rebase --continue
git rebase --abort
git rebase --skip
git merge --continue
git merge --abort
git cherry-pick --continue
git cherry-pick --abort
git cherry-pick --skip
git revert --continue
git revert --abort
git reset --hard
git checkout -- <path>
git restore --source=<tree> <path>
git add <path>
```

Package-manager, formatter, generated-code, and test commands are allowed only when they do not start, continue, abort, skip, or discard the Git operation and are appropriate for the repository.

## Resolution Heuristics

- Prefer preserving both sides when they are compatible.
- Prefer existing project conventions over introducing new abstractions.
- Prefer tests as executable evidence, but do not treat stale tests as product truth when code and docs indicate otherwise.
- Prefer explicit types and schemas over implicit behavior in typed codebases.
- Prefer editing the conflicted file directly over moving code elsewhere during conflict resolution.
- Avoid opportunistic refactors. Conflict resolution should produce the intended merged behavior with minimal unrelated churn.

## Stop And Ask Conditions

Stop and ask before proceeding if:

- The repository state suggests no conflict is currently in progress, but the user asked to resolve rebase conflicts.
- The only apparent fix is to discard one side's non-trivial work.
- The conflict touches secrets, credentials, auth/session behavior, billing, irreversible migrations, or production deployment configuration.
- The conflict resolution requires choosing between incompatible public APIs.
- The user asks you to continue, abort, skip, reset, discard, or stage and the exact requested action is unclear.
