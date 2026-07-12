---
name: address-pr-feedback
description: Use when the user wants to address, fix, resolve, or apply requested changes, review comments, or reviewer feedback on a pull request they are already working on; triggers on phrases like "fix the PR comments", "address review feedback", "resolve the requested changes". Assumes the user is already on the branch that needs the fixes.
metadata:
---

# Address PR Feedback

Use this skill to turn reviewer feedback on an existing PR into code changes that land in the right place in history. Assume the user is already on the branch the feedback applies to. Do not determine, checkout, or switch to a different branch as part of this skill.

The goal is not just to make the reviewer's complaints disappear — it is to fold each fix into the commit it actually belongs to, so the final history still reads as a clean, atomic, reviewable story, exactly as if the feedback had been caught before the PR was opened.

## Core Principles

- Assume the current branch is the correct target. Confirm it, but do not hunt for or switch to a different branch.
- Treat every review comment as a discrete requested change with its own resolution, not as one big blob of "PR feedback."
- Fixes belong in the commit that introduced the code being commented on, folded in with `--fixup`/`--autosquash`, not tacked on as a new commit at the tip of the branch.
- Only create a new commit when a requested change has no sensible home in existing history (e.g. a genuinely new addition the reviewer asked for).
- Never reword, retitle, or reshape an existing commit's message as a side effect of fixing it up. A commit's title describes what it does; addressing feedback about its correctness or implementation does not change what it does.
- Only change a commit's title when the business requirement or scope of that commit itself changed — and ask before doing it, even then.
- Match the branch's existing commit message style (prefixes, mood, length, ticket references, punctuation). Infer it from `git log`. If the branch has no established convention of its own (e.g. it's empty, or inconsistent), default to [Conventional Commits](https://www.conventionalcommits.org/) — this harness's baseline convention (see `atomic-commits` skill) — rather than inventing an ad hoc style.
- Keep commits atomic: don't bundle multiple unrelated review comments into one commit, and don't leave `fixup!`/`squash!`/WIP commits unresolved in the final history.
- Only rewrite commits that are unique to this branch. Never rebase, amend, or reorder commits that also exist on the base/default branch.
- Never force-push, reply to reviewer comments, or resolve review threads without explicit user approval of the exact plan.
- Use `gh` for GitHub operations when available.
- Ask whenever feedback is ambiguous, contradictory, contested, out of scope, or requires a product/business decision the user should own — do not silently guess or silently skip it.

## User Interaction Tools

Use the available user-question tool whenever the workflow says to ask the user.

- In OpenCode, use `question`. Because some clients render the structured question UI unreliably, **always also mirror the same question, its options, and your recommended option as plain chat text** in the same turn — never rely on the structured UI alone to carry the question.
- In Claude Code, use `askuserquestion` or the equivalent available ask-user tool.
- In Codex or other agents, use the available ask-user tool if present; otherwise ask directly in chat and wait for the answer before continuing.

Ask concise questions with recommended options when possible. Continue without asking only when the user already provided the needed information or the safe default is explicit in this skill.

## Required Workflow

### 1. Confirm Branch State

Confirm the current branch and that it looks like a real feature branch before doing anything else.

```bash
git status --short
git branch --show-current
git rev-parse --show-toplevel
```

Do not ask the user to choose a target branch — the assumption for this skill is that they are already on it. If `HEAD` is detached, or the current branch is the repository's default branch, stop and flag this: it usually means the user isn't actually on the PR branch yet. Ask before proceeding.

### 2. Determine The Base For Comparison

Identify the base branch so later steps can scope history correctly (which commits are "this branch's" versus inherited from the base).

```bash
gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'
git symbolic-ref refs/remotes/origin/HEAD --short
git merge-base --fork-point <base> HEAD
```

If a `gh pr view --json baseRefName` lookup is available for the current branch, prefer that over guessing the default branch.

### 3. Gather The Feedback To Address

Determine where the feedback lives. Ask if it isn't already clear from the user's message.

Recommended options:

- `GitHub PR Comments`: Pull review comments and threads for the PR tied to this branch.
- `Pasted Feedback`: The user will paste comments, a review summary, or a ticket comment directly.
- `Both`: Fetch GitHub feedback and merge it with anything the user pastes.

For GitHub PR comments:

```bash
gh pr view --json number,title,baseRefName,headRefName,headRefOid,reviews,comments
gh api repos/<owner>/<repo>/pulls/<number>/comments
gh api repos/<owner>/<repo>/issues/<number>/comments
```

For richer thread state (resolution status, line anchoring):

```bash
gh api graphql -f query='<query for pullRequest reviewThreads { nodes { id isResolved isOutdated path line comments { nodes { author { login } body } } } } }>'
```

If the user pastes feedback directly, use that as the source of truth and skip the GitHub fetch, but still confirm which PR/branch it corresponds to if relevant to resolving threads later.

### 4. Build The Feedback Checklist

Normalize every piece of feedback into a discrete, numbered item before writing any code. For each item capture:

- File and line (or area, if not line-anchored).
- Reviewer and quoted comment.
- Requested action, restated concretely.
- Type: `must-fix`, `suggestion/nit`, or `question` (questions may just need an answer, not a code change).
- Resolution status already visible on GitHub (resolved/unresolved), if applicable.

Deduplicate comments that point at the same underlying change. Flag anything that reads as a question rather than a change request — plan to answer it, not code it.

Present the checklist to the user before starting implementation. Ask about any item that is ambiguous, contested, out of scope, or requires a product/business call the user should make — don't guess and don't silently drop items.

### 5. Map Each Item To A Commit

For every checklist item, figure out which existing commit on this branch introduced the code being commented on.

```bash
git log --oneline <base>..HEAD
git log -p <base>..HEAD -- <path>
git log --oneline <base>..HEAD -- <path>
```

Classify each item as one of:

- `Fixup into commit <sha>`: the change belongs inside an existing commit.
- `New commit`: the requested change has no sensible home in existing history (a genuinely new addition).
- `Split across commits <sha1>, <sha2>, ...`: parts of the change belong in different commits.

Ask the user when it's genuinely unclear which commit a fix belongs to, or when a comment spans work introduced across several commits in a way that resists a clean split.

### 6. Confirm The Commit Message Style

Before creating any new commit, infer the branch's (and repo's) existing commit message conventions.

```bash
git log --format='%s' <base>..HEAD
git log --format='%s' -20
```

Look for prefix conventions (Conventional Commits, ticket IDs, all-caps type tags, etc.), mood (imperative vs. descriptive), and typical length. Reuse that exact style for any new commit created in this workflow. If nothing consistent is inferable, use Conventional Commits (`feat:`, `fix:`, `chore:`, `test:`, `docs:`, `refactor:`) — this harness's default (see `atomic-commits` skill) — imperative mood, ≤72-char subject. Do not introduce a third, different convention than either of these.

Do not reword any existing commit's title while fixing it up. If a mapped fix reveals that a commit's actual purpose or business requirement has changed — not just that it had a bug — stop and ask the user whether the title should change too before touching it.

### 7. Implement The Changes

Work through the checklist, implementing each requested change.

- Follow the repository's own contribution rules (AGENTS.md/CONTRIBUTING, lint/format/typecheck/test commands) the same as any other change.
- Keep edits scoped to what was actually requested — avoid opportunistic, unrelated changes while you're in the area.
- Update or add tests and docs in the same logical unit as the behavior they cover, so the eventual fixup keeps that commit self-consistent.
- If a comment is a question rather than a change request, draft an answer instead of writing code for it.

### 8. Fold Fixes Into The Right Commits

For each item mapped to an existing commit:

```bash
git add -p                      # stage only the hunks for this item
git commit --fixup=<sha>
```

Use `git add -p` (or path-scoped `git add <path>`) so unrelated hunks aren't swept into the wrong fixup. If a single requested change truly spans multiple commits, create one `--fixup` commit per target `<sha>`, staging only the relevant hunks each time.

Once all fixups for the current pass are created:

```bash
git rebase -i --autosquash <base>
```

Do not edit any commit message during this rebase unless the user has already approved a specific title change in step 6. For items classified as `New commit`, add them at the point in history that makes sense (commonly at the tip, unless the item logically precedes later commits), using the message style confirmed in step 6.

If a fixup does not apply cleanly during the rebase, stop, resolve the conflict in place (see `resolve-merge-conflicts` skill), re-run the narrowest relevant check, and continue the rebase.

### 9. Verify

Run the narrowest relevant checks first, then the fuller verification matrix the repository defines, before treating any item as resolved.

Prefer commands already documented in the repo (AGENTS.md, package scripts, CI config) over guessing. Re-run verification after the autosquash rebase completes, not just after the raw edits, since folding commits together can surface issues the pre-fixup state didn't have.

### 10. Re-Check The Resulting History

```bash
git log --oneline <base>..HEAD
git range-diff <old-tip>@{1} <base> HEAD   # if available, to see exactly what each fixup changed
```

Confirm:

- No leftover `fixup!`/`squash!`/WIP commits remain.
- No commit title changed except ones explicitly approved in step 6.
- Each commit is still coherent and self-contained.
- Commit order still tells a sensible implementation story.
- Nothing unrelated got swept into a commit via the `-p` staging.

### 11. Draft Replies For Reviewer Comments

For each checklist item, draft a specific reply: what changed, where, and (if useful) which commit now contains the fix. Group related replies to avoid noise, but do not send a single blanket "done" reply — be specific per thread.

If the user disagrees with a piece of feedback, do not silently skip it. Draft a reply explaining the reasoning (asking the user for that reasoning first if they haven't given it), and flag that item as pushback rather than resolved.

### 12. Preview Before Pushing Or Replying

Before pushing or touching GitHub in any way, present a complete preview and get explicit approval via the user-question tool (and its plain-text mirror, per "User Interaction Tools" above).

The preview must include:

- Updated `git log --oneline <base>..HEAD`.
- Which existing commits absorbed which feedback items.
- Any new commits added, with their exact messages.
- Verification results.
- Draft replies for each comment/thread, and which ones (if any) would be marked resolved.
- Any items intentionally left as pushback, with the reasoning to be shared with the reviewer.

Recommended confirmation options:

- `Push And Reply As Shown`: proceed with the exact preview.
- `Push Only`: rewrite history and push, but don't touch GitHub comments/threads yet.
- `Revise Plan`: ask what should change, regenerate the preview, and ask again.
- `Do Not Push`: leave the rewritten history local only.

### 13. Push And Reply (Only After Approval)

History was rewritten via interactive rebase, so pushing requires a force push. Warn about the implications for anyone else who has pulled this branch. Always use `--force-with-lease`, never a bare `--force` — see `worktree-workflow` skill for why this harness never uses bare `--force`.

```bash
git push --force-with-lease
```

Reply to comments or resolve threads only if the user asked for that in step 12:

```bash
gh api repos/<owner>/<repo>/pulls/<number>/comments/<comment_id>/replies -f body="<reply>"
gh api graphql -f query='mutation { resolveReviewThread(input: {threadId: "<id>"}) { thread { isResolved } } }'
```

Resolving a thread is sometimes a call the original reviewer expects to make themselves — confirm whether the user wants threads resolved by this workflow or wants to leave that to the reviewer, and only resolve on explicit instruction.

### 14. Report Final State

Summarize:

- What was pushed and the new `headRefOid`.
- Which comments were replied to or resolved, and which weren't touched.
- Any items left as pushback, with the reasoning shared.
- Anything that failed to apply cleanly or still needs the user's input.

## Commit Mapping Checklist

- Every requested change is either folded into the commit that introduced the code it concerns, or deliberately promoted to its own new commit — never just appended to the tip by default.
- No commit mixes two unrelated review comments.
- No commit's title changed unless the user explicitly approved a business-requirement-driven rename.
- New commits (if any) match the branch's existing message style, or Conventional Commits if the branch had none.
- The final history has no `fixup!`/`squash!`/WIP artifacts.
- Only commits unique to this branch were touched; nothing shared with the base branch was rebased.
- Commit order after the rebase still reads as a coherent implementation story.

## Important Constraints

- Do not determine, checkout, or switch branches — assume the user is already on the correct one.
- Do not force-push, reply to comments, or resolve review threads without explicit approval of the exact preview.
- Do not reword, retitle, or reshape an existing commit's message as a byproduct of fixing it up.
- Do not change a commit's title unless the user explicitly confirms the business requirement/scope of that commit changed.
- Do not impose a commit message convention the branch doesn't already use (fall back to Conventional Commits only when the branch has no inferable convention).
- Do not bundle multiple unrelated review comments into a single commit.
- Do not rebase, amend, or reorder any commit that also exists on the base branch.
- Do not silently drop, ignore, or auto-resolve feedback the user disagrees with — surface it back to the user and reviewer instead.
- Do not leave temporary fixup/WIP commits in the final history.
- Do not expose secrets found while inspecting comments or diffs; if secret material is exposed, say so without repeating it.
- Never use bare `git push --force` — always `--force-with-lease`.
