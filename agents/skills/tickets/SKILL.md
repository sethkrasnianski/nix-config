---
name: tickets
description: Manage repository GitHub issues as tickets in an approved GitHub Projects V2 built-in Kanban project. Use when asked to set up, add, file, list, start, resume, move, prioritize, complete, close, or inspect ticket history.
---

# GitHub Projects tickets

Treat a repository GitHub issue and its corresponding project item as one
ticket. The project is the board and the issue is the durable ticket record.
This skill currently supports only the captured built-in Kanban profile
`kanban-v1`. It does not adapt arbitrary Projects V2 projects, infer a template
from a title, or support the other built-in templates yet.

The installed contract is
`$TICKETS_SKILL_DIR/contracts/kanban-v1.json`. The helper at
`$TICKETS_SKILL_DIR/scripts/project-contract.sh` snapshots and verifies the
API-visible project structure. Use it rather than hand-comparing API output.
These are files belonging to the global skill installation, not the target
repository.

Set the skill directory once in the shell where you run the commands. Override
it if the shared skill was installed somewhere other than `~/.agents`:

```sh
export TICKETS_SKILL_DIR="${TICKETS_SKILL_DIR:-$HOME/.agents/skills/tickets}"
```

## Safety boundaries

- Never create or modify a project as a substitute for the built-in Kanban
  setup. `gh project create` and `gh project copy` are not template provenance.
- Never silently repair, convert, relink, rename, or delete a non-matching
  project.
- Never treat `ProjectV2.template` as the source template used to create a
  project. It identifies whether the project itself is an organization
  template, not its creation provenance.
- Never modify required fields, status options, views, layouts, filters,
  grouping, sorting, or workflows. User-added fields and views are acceptable
  only after adoption and only when the required baseline remains unchanged.
- Do not write a local `.projects/` board, ticket ID, or per-ticket plan file.
  Use the GitHub issue, project item, comments, commits, and pull request as
  durable context.
- Do not put tokens, credentials, or private issue content in tracked files.

## Authentication and repository resolution

Before a project operation, check authentication and the current repository:

```sh
gh auth status
gh repo view --json nameWithOwner,url
```

Project reads require `read:project`; issue creation and project mutations
require the `project` scope. If the scope is missing, ask the user to run:

```sh
gh auth refresh --hostname github.com -s project
```

Split `nameWithOwner` into `REPO_OWNER` and `REPO_NAME`. The project owner can
be the repository owner or the authenticated user, so do not assume the two
owners are identical. Resolve the project owner and number before operating on
items.

## Project setup and verification

Every operation starts by identifying one active, repository-linked, verified
Kanban project. Do not select by title alone.

1. List candidate projects for the repository owner and, when different, the
   authenticated user:

   ```sh
   gh project list --owner "$PROJECT_OWNER" --closed --limit 100 --format json
   ```

2. For each candidate, snapshot the project. The snapshot query paginates
   repositories, fields, views, and workflows and rejects a nested view
   connection that is not fully visible:

   ```sh
   "$TICKETS_SKILL_DIR/scripts/project-contract.sh" snapshot \
     --owner "$PROJECT_OWNER" --number "$PROJECT_NUMBER" \
     --output "$TMPDIR/project.json"
   ```

3. Verify both the structural contract and repository linkage:

   ```sh
   "$TICKETS_SKILL_DIR/scripts/project-contract.sh" verify \
     --contract "$TICKETS_SKILL_DIR/contracts/kanban-v1.json" \
     --snapshot "$TMPDIR/project.json" \
     --repository "$REPO_OWNER/$REPO_NAME"
   ```

4. Require `closed == false` from the raw project metadata. A project with
   incomplete pagination, missing required status options, altered required
   views, an invalid marker, or an unrelated template is rejected.
   The captured Kanban profile uses `Backlog` as its initial status, `In
   progress` as its active status, and `Done` as its terminal status; it also
   exposes `In review` and `Ready`. Use the exact option spelling and IDs from
   the captured contract. If a future contract has different or ambiguous
   status roles, stop and ask rather than guessing.
5. If more than one candidate verifies, ask the user which project to use. Do
   not guess from recency, title, or item count.
6. If no candidate verifies, stop ticket work and explain the setup path below.

An unmarked project is accepted only when its normalized structure matches the
pristine contract exactly. After the user confirms that it was created from an
untouched built-in Kanban card, adopt it:

```sh
"$TICKETS_SKILL_DIR/scripts/project-contract.sh" adopt \
  --owner "$PROJECT_OWNER" --number "$PROJECT_NUMBER" \
  --repository "$REPO_OWNER/$REPO_NAME" \
  --contract "$TICKETS_SKILL_DIR/contracts/kanban-v1.json"
```

`adopt` re-snapshots and re-verifies the project, then appends exactly one
versioned marker to the existing project README. It never replaces README
content. Future operations require that marker and the unchanged required
baseline; extra user fields and views are allowed.

The public API does not expose historical source-template provenance. Matching
the normalized contract is the strongest API-only check available, not proof
of how the project was created. Do not claim stronger provenance.

## No-argument board view

For a request to show or list tickets:

1. Verify the project first.
2. Fetch all project items, not just the default page:

   ```sh
   gh project item-list "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" \
     --limit 100 --format json
   ```

   If the result is truncated, use the corresponding paginated GraphQL
   `ProjectV2.items` query instead of presenting a partial board.
3. Show issue number, title, URL, open/closed state, and the exact Kanban
   status. Preserve the project/view order; do not sort by title unless the
   verified view contract specifies that ordering.
4. Report items that are drafts, archived, missing content, or missing a
   status rather than silently dropping them.

## Add or file a ticket

Trigger this workflow for requests such as “add a ticket”, “file a bug”, or
“create an issue”.

1. Verify the project and resolve its exact `Status` field and options from
   the verified contract. Do not assume a similarly named field in an
   unverified project.
2. Search existing open and closed issues before drafting a new one:

   ```sh
   gh issue list --repo "$REPO_OWNER/$REPO_NAME" --state all \
     --search "$SEARCH_TERMS" --limit 50 \
     --json number,title,state,url
   ```

   Show plausible duplicates and ask whether to reuse or create a new issue.
3. Inspect repository issue templates. Use the GraphQL
   `Repository.issueTemplates` connection with complete pagination and retain
   `name`, `filename`, `about`, `body`, `title`, `labels`, `assignees`, and
   `type`. If exactly one template fits, use it. If several are plausible,
   show the choices and ask the user. If none exists, use a concise fallback
   body with summary, expected behavior, acceptance criteria, and relevant
   verification information.
4. Show the proposed title, complete body, labels, assignees, and target
   project before writing. Ask for confirmation when the request did not
   already unambiguously authorize creation.
5. Create a repository issue. Use a temporary body file rather than putting
   multiline content or credentials in shell history:

   ```sh
   gh issue create --repo "$REPO_OWNER/$REPO_NAME" \
     --title "$TITLE" --body-file "$TMPDIR/issue-body.md"
   ```

6. Add the returned issue URL to the verified project exactly once:

   ```sh
   gh project item-add "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" \
     --url "$ISSUE_URL" --format json
   ```

7. Set the new item to the contract's `Backlog` status explicitly, then
   re-list it and verify the status. If issue creation succeeds but item-add
   or status update fails, report the issue URL and the failed operation; do
   not silently delete or recreate the issue.

Issue forms may declare a `projects` entry that auto-adds an issue. Still check
the target project's item list after creation, avoid duplicate items, and set
the required initial status explicitly.

## Start or resume work

Trigger this workflow for “work on issue 42”, “start the ticket”, or “resume
the next ticket”. GitHub issue numbers and URLs are the identifiers; do not
invent local IDs.

1. Verify the project.
2. Read the complete issue and its comments:

   ```sh
   gh issue view "$ISSUE_NUMBER" --repo "$REPO_OWNER/$REPO_NAME" \
     --comments --json number,title,body,state,author,labels,assignees,comments,url
   ```

3. Confirm that exactly one corresponding project item exists. If it is
   absent, ask before adding it. If duplicates exist, stop and ask which item
   to retain; never silently merge them.
4. Move the item to the contract's `In progress` status before implementation:

   ```sh
   gh project item-edit "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" \
     --id "$ITEM_ID" --field-id "$STATUS_FIELD_ID" \
     --project-id "$PROJECT_ID" --single-select-option-id "$IN_PROGRESS_OPTION_ID"
   ```

   Name-based `--url ... --field Status --value ...` is acceptable for an
   interactive one-off, but IDs obtained from the verified project are safer
   for scripts. Re-read the item after every mutation.
5. Treat the issue body, comments, linked pull requests, and repository
   instructions as the implementation context. Record material decisions in
   the issue or its comments, not in a new local ticket database.

## Move and prioritize tickets

Use the exact status option names and IDs from the verified project. For a
single item, `gh project item-edit` updates its status. For explicit ordering,
use the public GraphQL mutation and a verified project/item ID:

```sh
gh api graphql \
  -f query='mutation($projectId:ID!, $itemId:ID!, $afterId:ID) {
    updateProjectV2ItemPosition(input:{projectId:$projectId,
      itemId:$itemId, afterId:$afterId}) {
      projectV2Item { id }
    }
  }' \
  -F projectId="$PROJECT_ID" -F itemId="$ITEM_ID" \
  -F afterId="$PREVIOUS_ITEM_ID"
```

Use `afterId` as `null` to move an item to the beginning. Preserve the
project's ordering semantics and verify the new order with a fresh item-list
query. Do not reorder by mutating titles or issue numbers.

## Complete a ticket

Only complete a ticket after its approved implementation and all discovered
verification commands pass.

1. Record the implementation and verification result in the issue or linked
   pull request.
2. Set the project item to the exact done option from the contract and verify
   it.
3. Close the repository issue:

   ```sh
   gh issue close "$ISSUE_NUMBER" --repo "$REPO_OWNER/$REPO_NAME" \
     --reason completed
   ```

4. Re-read both issue and project item. If either mutation fails, report the
   divergence and leave the other result visible; never claim completion when
   the two records disagree.

Do not delete completed issues or project items. They are the ticket history.

## History lookup

Use immutable GitHub issue numbers and URLs for history:

```sh
gh issue view "$ISSUE_NUMBER" --repo "$REPO_OWNER/$REPO_NAME" --comments
git log --oneline --all --grep="#${ISSUE_NUMBER}"
```

If the repository uses a different issue-reference convention, follow its
existing commit and pull-request style rather than inventing a local prefix.
