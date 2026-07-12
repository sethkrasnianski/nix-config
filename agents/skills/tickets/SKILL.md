---
name: tickets
description: Manage a repository's local ticket board and durable implementation plans under .projects/. Use to bootstrap ticket tracking, add or list tickets, work the next ticket, resume a ticket in a fresh session, or inspect ticket history.
---

# Tickets

Use `.projects/config.json` as the repository's source of truth for project
work. Keep durable, fresh-session implementation context in
`.projects/plans/<ticket-id>.md`.

## Bootstrap

Before any ticket operation, locate the repository root and check for
`.projects/config.json`.

If it does not exist:

1. Explain that ticket tracking needs to be initialized.
2. Ask the user for a short project prefix. Recommend 2-5 uppercase ASCII
   letters derived from the project name, but let the user choose it.
3. Validate the prefix against `^[A-Z][A-Z0-9]{1,4}$`. If it is invalid, ask
   again rather than silently transforming it.
4. Show the proposed initial configuration and obtain confirmation before
   writing.
5. Create `.projects/plans/` and `.projects/config.json`:

```json
{
  "prefix": "MF",
  "next_id": 1,
  "tickets": []
}
```

Never overwrite an existing `.projects/config.json`. If it exists but is
invalid, report the exact validation problem and ask before repairing it.

## Board contract

```json
{
  "prefix": "MF",
  "next_id": 18,
  "tickets": [
    {
      "id": "MF-17",
      "type": "feature",
      "title": "Add rate limiting",
      "description": "Implement per-client upload limits and return a clear response when the limit is exceeded.",
      "lane": "todo",
      "plan": "plans/MF-17.md"
    }
  ]
}
```

- `prefix` is immutable after tickets exist unless the user explicitly
  approves a migration of every ticket and plan filename.
- `next_id` is a positive integer that only increments. IDs are never reused,
  deleted, or renumbered.
- `type` is one of `feature`, `bug`, or `chore`.
- `lane` is one of `backlog`, `todo`, or `complete`.
- `plan` is relative to `.projects/` and must be
  `plans/<ticket-id>.md`.
- Array order within each lane is priority; the first `todo` ticket is next.
- Keep completed tickets and plans as project history.

## No arguments: show the board

List tickets grouped in `backlog`, `todo`, `complete` order. Preserve array
order within each lane and render each ticket as:

```text
MF-17 [feature] Add rate limiting
```

Also flag malformed entries or missing plan files without rewriting anything.

## Add mode

Triggered by requests such as "add a ticket" or "file a bug".

1. Clarify genuinely ambiguous requirements. Confirm `type` and `lane` when
   they are not clear; default the proposed lane to `todo`.
2. Draft a short imperative title and a 1-3 sentence description sufficient
   for a future session to understand the requested outcome.
3. Show the complete draft and ask for confirmation before writing.
4. Allocate `<prefix>-<next_id>`, increment `next_id`, append the ticket in
   priority order for its lane, and set `plan` to `plans/<ticket-id>.md`.
5. Create the corresponding plan file from the durable plan template below.

Do not implement a newly added ticket unless the user also asked to work it.

## Plan contract

The plan file is the durable context a fresh session reads before working or
resuming a ticket. Keep it concise and factual:

```markdown
# MF-17: Add rate limiting

## Ticket
- Type: feature
- Lane: todo
- Description: Implement per-client upload limits and return a clear response when the limit is exceeded.

## Goal and acceptance criteria
- ...

## Implementation plan
1. ...

## Relevant context
- Files and architecture: ...
- Repository conventions: ...
- Verification commands: ...

## Decisions and discoveries
- ...

## Status
- Planned
```

- Create the file when the ticket is added, even if some sections remain
  explicitly `TBD` pending implementation research.
- Before implementation, inspect the repository and replace `TBD` content with
  a concrete plan. Ask for approval when the plan introduces a meaningful
  product, security, data, or architectural decision.
- Update decisions, discoveries, verification commands, and status whenever
  they materially change. Do not use the plan as a verbose activity log.
- On a fresh session, read both the ticket entry and its plan before acting.
- On completion, set status to `Complete` and briefly record verification
  results. Never delete the plan.

## Work mode

Triggered by requests such as "work on MF-17", "resume MF-17", "do the next
ticket", or "pick up a ticket".

1. Resolve the named ticket, or select the first ticket in `todo`. If `todo`
   is empty, ask before moving the first backlog ticket to `todo`.
2. Read repository instructions and the ticket's plan. Discover documented
   test, lint, typecheck, build, formatting, and commit conventions; never
   invent commands that are not discoverable.
3. Research the affected code and update the plan into an implementation-ready
   artifact. Preserve any approval or TDD workflow required by the repository.
4. Implement only the ticket's approved scope.
5. Run every relevant discovered verification command. Do not mark the ticket
   complete while required verification is failing.
6. Update the plan status and verification results, move the ticket to
   `complete`, and commit the implementation, plan, and board metadata as one
   coherent ticket change unless repository instructions explicitly require
   finer-grained commits.

## Commit convention

Before committing, inspect `AGENTS.md`, `CLAUDE.md`, contributing guidance,
and recent commit subjects. Follow an explicit or clearly established
repository convention, including its placement of ticket IDs.

If no convention can be determined, use exactly one of:

```text
feat: <imperative title>
fix: <imperative title>
chore: <imperative title>
```

Map `feature` to `feat`, `bug` to `fix`, and `chore` to `chore`. The colon must
be followed by one space. Add a concise commit body describing what the
ticket's implementation and plan metadata now deliver, and include the ticket
ID there when it is not already present in the prescribed subject format.

Example fallback commit:

```text
feat: add upload rate limiting

Implement MF-17's per-client upload limits and persist its approved plan,
verification results, and completed ticket metadata.
```

Do not mark the ticket complete or create the completion commit if required
verification has not passed.

## History lookup

Find shipped work by searching the immutable ticket ID across commit subjects
and bodies:

```sh
git log --oneline --grep 'MF-17'
```
