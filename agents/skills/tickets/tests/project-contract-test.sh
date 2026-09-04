#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/project-contract.sh"
CONTRACT="$ROOT/contracts/kanban-v1.json"
RAW="$ROOT/fixtures/kanban-v1.raw.json"
REPOSITORY="octo/example"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

fail() {
  printf 'failure: %s\n' "$*" >&2
  exit 1
}

jq -e '
  .schemaVersion == 1 and
  .pagination.complete == true and
  .project.template == false and
  .project.closed == false and
  (.repositories | length) == 1 and
  .repositories[0].nameWithOwner == "octo/example" and
  (.fields | length) == 18 and
  (.views | length) == 5 and
  (.workflows | length) == 7 and
  all(.views[];
    .fields.pageInfo == {hasNextPage: false, endCursor: null} and
    .configuration.visibleFields.pageInfo == {hasNextPage: false, endCursor: null} and
    .groupByFields.pageInfo == {hasNextPage: false, endCursor: null} and
    .sortByFields.pageInfo == {hasNextPage: false, endCursor: null} and
    .verticalGroupByFields.pageInfo == {hasNextPage: false, endCursor: null})
' "$RAW" >/dev/null || fail "raw fixture is not a complete production-shaped snapshot"

bash "$SCRIPT" capture-contract --snapshot "$RAW" \
  --output "$TEMP_DIR/captured.json"
jq -S -n -e --slurpfile captured "$TEMP_DIR/captured.json" \
  --slurpfile expected "$CONTRACT" \
  '$captured[0] == $expected[0]' >/dev/null || \
  fail "capture-contract did not produce the captured production contract"

jq -e '
  ([.fields[].name] | sort) == [
    "Assignees", "Closed", "Created", "Estimate", "Labels",
    "Linked pull requests", "Milestone", "Parent issue", "Priority",
    "Repository", "Reviewers", "Size", "Start date", "Status",
    "Sub-issues progress", "Target date", "Title", "Updated"
  ] and
  ([.views[].name] | sort) ==
    ["Backlog", "My items", "Priority board", "Roadmap", "Team items"] and
  ([.workflows[].name] | sort) == [
    "Auto-add sub-issues to project", "Auto-add to project",
    "Auto-close issue", "Item added to project", "Item closed",
    "Pull request linked to issue", "Pull request merged"
  ] and
  ([.fields[] | select(.name == "Status") | .options[].name] | sort) ==
    ["Backlog", "Done", "In progress", "In review", "Ready"] and
  ([.fields[] | select(.name == "Priority") | .options[].name] | sort) ==
    ["P0", "P1", "P2"] and
  ([.fields[] | select(.name == "Size") | .options[].name] | sort) ==
    ["L", "M", "S", "XL", "XS"]
' "$TEMP_DIR/captured.json" >/dev/null || \
  fail "captured contract lost a production baseline component"

result="$(bash "$SCRIPT" verify --contract "$CONTRACT" --snapshot "$RAW" \
  --repository "$REPOSITORY")" || fail "raw fixture should be accepted"
[[ "$(jq -r '.valid' <<<"$result")" == true ]] || \
  fail "raw fixture was not valid"
[[ "$(jq -r '.mode' <<<"$result")" == pristine ]] || \
  fail "raw fixture had the wrong verification mode"

external_result="$(
  cd "$TEMP_DIR"
  bash "$SCRIPT" verify --contract "$CONTRACT" --snapshot "$RAW" \
    --repository "$REPOSITORY"
)" || fail "the skill helper should work outside its source repository"
[[ "$(jq -r '.mode' <<<"$external_result")" == pristine ]] || \
  fail "external-directory verification returned the wrong mode"

printf 'project contract tests passed\n'
