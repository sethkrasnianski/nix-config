#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASH="$(command -v bash)"
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

if grep -Fq '### Capturing the first contract' "$ROOT/SKILL.md" || \
  grep -Fq 'pending-canonical-capture' "$ROOT/SKILL.md"; then
  fail "tickets skill still claims that kanban-v1 needs canonical capture"
fi

jq -e '
  .schemaVersion == 1 and
  .pagination.complete == true and
  .project.template == false and
  .project.closed == false and
  (.repositories | length) == 2 and
  any(.repositories[]; .nameWithOwner == "octo/example") and
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

assert_mode() {
  local snapshot="$1" expected="$2" result
  result="$(bash "$SCRIPT" verify --contract "$CONTRACT" \
    --snapshot "$snapshot" --repository "$REPOSITORY")" || \
    fail "$(basename "$snapshot") should be accepted"
  jq -e --arg expected "$expected" \
    '.valid == true and .mode == $expected and .contractVersion == "kanban-v1"' \
    <<<"$result" >/dev/null || fail "$(basename "$snapshot") was not a valid $expected project"
}

run_capture() {
  local stdout_file="$1" stderr_file="$2"
  shift 2
  set +e
  "$@" >"$stdout_file" 2>"$stderr_file"
  COMMAND_STATUS=$?
  set -e
}

assert_error() {
  local snapshot="$1" expected="$2" stdout_file="$TEMP_DIR/stdout" \
    stderr_file="$TEMP_DIR/stderr"
  run_capture "$stdout_file" "$stderr_file" bash "$SCRIPT" verify \
    --contract "$CONTRACT" --snapshot "$snapshot" --repository "$REPOSITORY"
  [[ "$COMMAND_STATUS" -ne 0 ]] || \
    fail "$(basename "$snapshot") should be rejected"
  [[ ! -s "$stdout_file" ]] || \
    fail "$(basename "$snapshot") produced a structural result before its guard"
  [[ "$(<"$stderr_file")" == "error: $expected" ]] || \
    fail "$(basename "$snapshot") produced the wrong diagnostic"
}

assert_incomplete_pagination() {
  local snapshot="$1" stdout_file="$TEMP_DIR/stdout" \
    stderr_file="$TEMP_DIR/stderr" error_output
  run_capture "$stdout_file" "$stderr_file" bash "$SCRIPT" verify \
    --contract "$CONTRACT" --snapshot "$snapshot" --repository "$REPOSITORY"
  [[ "$COMMAND_STATUS" -ne 0 ]] || \
    fail "$(basename "$snapshot") should be rejected"
  [[ ! -s "$stdout_file" ]] || \
    fail "$(basename "$snapshot") produced a structural result before normalization"
  error_output="$(<"$stderr_file")"
  [[ "$error_output" == *"snapshot pagination is incomplete"* ]] || \
    fail "$(basename "$snapshot") omitted the incomplete pagination diagnostic"
  [[ "$error_output" == *"error: unable to normalize snapshot: $snapshot"* ]] || \
    fail "$(basename "$snapshot") omitted the normalization failure"
}

assert_rejected() {
  local snapshot="$1" stdout_file="$TEMP_DIR/stdout" \
    stderr_file="$TEMP_DIR/stderr" result
  run_capture "$stdout_file" "$stderr_file" bash "$SCRIPT" verify \
    --contract "$CONTRACT" --snapshot "$snapshot" --repository "$REPOSITORY"
  [[ "$COMMAND_STATUS" -ne 0 ]] || \
    fail "$(basename "$snapshot") should be rejected"
  [[ ! -s "$stderr_file" ]] || \
    fail "$(basename "$snapshot") failed before structural verification"
  result="$(<"$stdout_file")"
  jq -e '.valid == false and .mode == "rejected" and .contractVersion == "kanban-v1"' \
    <<<"$result" >/dev/null || \
    fail "$(basename "$snapshot") did not produce a structural rejection"
}

create_gh_double() {
  local gh="$TEMP_DIR/bin/gh"
  cat >"$gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

FIXTURE="${GH_DOUBLE_FIXTURE:?}"
LOG="${GH_DOUBLE_LOG:?}"
MODE="${GH_DOUBLE_MODE:-snapshot}"

if [[ "${1:-}" == api && "${2:-}" == graphql ]]; then
  shift 2
  query=''
  login=''
  number=''
  id=''
  repositories_cursor=''
  fields_cursor=''
  views_cursor=''
  workflows_cursor=''

  while (($#)); do
    case "$1" in
      -f)
        key="${2%%=*}"
        value="${2#*=}"
        case "$key" in
          query) query="$value" ;;
          login) login="$value" ;;
          repositoriesCursor) repositories_cursor="$value" ;;
          fieldsCursor) fields_cursor="$value" ;;
          viewsCursor) views_cursor="$value" ;;
          workflowsCursor) workflows_cursor="$value" ;;
        esac
        shift 2
        ;;
      -F)
        if [[ "$2" == *=* ]]; then
          key="${2%%=*}"
          value="${2#*=}"
          shift 2
        else
          key="$2"
          value="$3"
          shift 3
        fi
        case "$key" in
          number) number="$value" ;;
          id) id="$value" ;;
        esac
        ;;
      *)
        shift
        ;;
    esac
  done

  if [[ "$query" == *"projectV2(number:"* ]]; then
    if [[ "$login" != octo || "$number" != 15 ]]; then
      printf 'unexpected project lookup target\n' >&2
      exit 1
    fi
    jq -cn --arg owner "$login" --arg number "$number" \
      '{kind: "project-id", owner: $owner, number: $number}' >>"$LOG"
    printf '%s\n' '{"data":{"repositoryOwner":{"projectV2":{"id":"project-fixture"}}}}'
    exit 0
  fi

  if [[ "$id" != project-fixture ]]; then
    printf 'unexpected project snapshot target\n' >&2
    exit 1
  fi
  jq -cn \
    --arg id "$id" \
    --arg repositories_cursor "$repositories_cursor" \
    --arg fields_cursor "$fields_cursor" \
    --arg views_cursor "$views_cursor" \
    --arg workflows_cursor "$workflows_cursor" \
    '{kind: "snapshot", id: $id, repositoriesCursor: $repositories_cursor,
      fieldsCursor: $fields_cursor, viewsCursor: $views_cursor,
      workflowsCursor: $workflows_cursor}' >>"$LOG"

  jq -n --slurpfile source "$FIXTURE" \
    --arg repositories_cursor "$repositories_cursor" \
    --arg fields_cursor "$fields_cursor" \
    --arg views_cursor "$views_cursor" \
    --arg workflows_cursor "$workflows_cursor" \
    --arg mode "$MODE" '
    $source[0] as $source |
    def page($items; $cursor; $size; $next):
      if $cursor == "" then
        {nodes: $items[0:$size],
         pageInfo: {hasNextPage: (($items | length) > $size),
                    endCursor: (if (($items | length) > $size)
                                then $next else null end)}}
      else
        {nodes: $items[($size - 1):],
         pageInfo: {hasNextPage: false, endCursor: null}}
      end;
    ($source.project + {
      repositories: page($source.repositories; $repositories_cursor; 1;
                         "repositories-page-2"),
      fields: page($source.fields; $fields_cursor; 9; "fields-page-2"),
      views: page($source.views; $views_cursor; 2; "views-page-2"),
      workflows: page($source.workflows; $workflows_cursor; 4;
                      "workflows-page-2")
    }) as $node |
    {data: {node: $node}} |
    if $mode == "nested-pagination" then
      .data.node.views.nodes[0].fields.pageInfo = {
        hasNextPage: true, endCursor: "nested-page-2"
      }
    else . end
  '
  exit 0
fi

if [[ "${1:-}" == project && "${2:-}" == edit ]]; then
  shift 2
  number="$1"
  shift
  owner=''
  readme=''
  while (($#)); do
    case "$1" in
      --owner) owner="$2"; shift 2 ;;
      --readme) readme="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  if [[ "$owner" != octo || "$number" != 15 ]]; then
    printf 'unexpected project edit target\n' >&2
    exit 1
  fi
  if [[ "$MODE" == "edit-fails" ]]; then
    exit 1
  fi
  jq -cn --arg owner "$owner" --arg number "$number" --arg readme "$readme" \
    '{kind: "edit", owner: $owner, number: $number, readme: $readme}' >>"$LOG"
  exit 0
fi

printf 'unexpected gh invocation\n' >&2
exit 1
EOF
  chmod +x "$gh"
}

jq '.repositories |= map(.nameWithOwner = "octo/other")' "$RAW" \
  >"$TEMP_DIR/unrelated-repository.json"
jq '.project.template = true' "$RAW" >"$TEMP_DIR/template.json"
jq '.project.closed = true' "$RAW" >"$TEMP_DIR/closed.json"
jq '.pagination.complete = false' "$RAW" \
  >"$TEMP_DIR/incomplete-pagination.json"
jq '.fields |= map(select(.name != "Status"))' "$RAW" \
  >"$TEMP_DIR/missing-status.json"
jq '.fields |= map(
  if .name == "Status" then .options |= map(select(.name != "Ready"))
  else . end
)' "$RAW" >"$TEMP_DIR/missing-status-option.json"
assert_error "$TEMP_DIR/unrelated-repository.json" \
  "project is not linked to repository octo/example"
assert_error "$TEMP_DIR/template.json" \
  "organization project templates cannot be used as ticket boards"
assert_error "$TEMP_DIR/closed.json" \
  "closed projects cannot be used as ticket boards"
assert_incomplete_pagination "$TEMP_DIR/incomplete-pagination.json"
assert_rejected "$TEMP_DIR/missing-status.json"
assert_rejected "$TEMP_DIR/missing-status-option.json"

MARKER='<!-- github-projects-tickets: kanban-v1 -->'
jq --arg marker "$MARKER" '
  .project.readme = $marker |
  .fields += [{
    __typename: "ProjectV2Field",
    id: "field-personal-notes",
    name: "Personal notes",
    dataType: "TEXT",
    isIssueField: false
  }] |
  .views += [{
    id: "view-personal-notes",
    number: 99,
    name: "Personal notes",
    layout: "TABLE_LAYOUT",
    filter: "",
    fields: {nodes: [], pageInfo: {hasNextPage: false, endCursor: null}},
    configuration: {visibleFields: {
      nodes: [], pageInfo: {hasNextPage: false, endCursor: null}
    }},
    groupByFields: {nodes: [], pageInfo: {hasNextPage: false, endCursor: null}},
    sortByFields: {nodes: [], pageInfo: {hasNextPage: false, endCursor: null}},
    verticalGroupByFields: {nodes: [], pageInfo: {
      hasNextPage: false, endCursor: null
    }}
  }]
' "$RAW" >"$TEMP_DIR/marked-superset.json"
jq '.fields |= map(
  if .name == "Estimate" then .dataType = "DATE" else . end
)' "$TEMP_DIR/marked-superset.json" >"$TEMP_DIR/altered-field.json"
jq '.views |= map(
  if .name == "Backlog" then .filter = "status:Ready" else . end
)' "$TEMP_DIR/marked-superset.json" >"$TEMP_DIR/altered-view.json"
jq '.fields |= map(
  if .name == "Status" then
    .options |= map(if .name == "Ready" then .color = "RED" else . end)
  else . end
)' "$TEMP_DIR/marked-superset.json" >"$TEMP_DIR/altered-status-option.json"
jq '.workflows |= map(
  if .name == "Item closed" then .enabled = false else . end
)' "$TEMP_DIR/marked-superset.json" >"$TEMP_DIR/altered-workflow.json"
jq '.workflows += [{
  id: "workflow-unexpected",
  number: 99,
  name: "Unexpected workflow",
  enabled: true
}]' "$TEMP_DIR/marked-superset.json" >"$TEMP_DIR/extra-workflow.json"
jq '.project.readme = "<!-- github-projects-tickets: not-kanban-v1 -->"' "$RAW" \
  >"$TEMP_DIR/malformed-marker.json"
jq --arg marker "$MARKER" '.project.readme = ($marker + "\n" + $marker)' \
  "$RAW" >"$TEMP_DIR/duplicate-marker.json"
jq '.fields += [{
  __typename: "ProjectV2Field",
  id: "field-personal-notes",
  name: "Personal notes",
  dataType: "TEXT",
  isIssueField: false
}]' "$RAW" >"$TEMP_DIR/customized-unmarked.json"
jq '.fields |= map(
  if .name == "Estimate" then .name = "Unrelated field" else . end
)' "$RAW" >"$TEMP_DIR/unrelated-structure.json"
assert_mode "$TEMP_DIR/marked-superset.json" marked-superset
assert_rejected "$TEMP_DIR/altered-field.json"
assert_rejected "$TEMP_DIR/altered-view.json"
assert_rejected "$TEMP_DIR/altered-status-option.json"
assert_rejected "$TEMP_DIR/altered-workflow.json"
assert_rejected "$TEMP_DIR/extra-workflow.json"
assert_rejected "$TEMP_DIR/malformed-marker.json"
assert_rejected "$TEMP_DIR/duplicate-marker.json"
assert_rejected "$TEMP_DIR/customized-unmarked.json"
assert_rejected "$TEMP_DIR/unrelated-structure.json"

SNAPSHOT_OUTPUT="$TEMP_DIR/snapshot.json"
SNAPSHOT_LOG="$TEMP_DIR/snapshot.log"
mkdir -p "$TEMP_DIR/bin"
create_gh_double
PATH="$TEMP_DIR/bin:$PATH" GH_DOUBLE_MODE=snapshot \
  GH_DOUBLE_LOG="$SNAPSHOT_LOG" \
  GH_DOUBLE_FIXTURE="$RAW" "$BASH" "$SCRIPT" snapshot \
  --owner octo --number 15 --output "$SNAPSHOT_OUTPUT" || \
  fail "snapshot should use a deterministic local GitHub double"

if ! jq -S -n -e --slurpfile actual "$SNAPSHOT_OUTPUT" \
  --slurpfile expected "$RAW" \
  '($actual[0] | .repositories |= sort_by(.id)) ==
   ($expected[0] | .repositories |= sort_by(.id))' >/dev/null; then
  fail "paginated snapshot did not match the sanitized raw fixture"
fi
jq -s -e '
  length == 3 and
  .[0].kind == "project-id" and
  .[1].kind == "snapshot" and
  .[1].id == "project-fixture" and
  .[1].repositoriesCursor == "" and
  .[1].fieldsCursor == "" and
  .[1].viewsCursor == "" and
  .[1].workflowsCursor == "" and
  .[2].kind == "snapshot" and
  .[2].id == "project-fixture" and
  .[2].repositoriesCursor == "repositories-page-2" and
  .[2].fieldsCursor == "fields-page-2" and
  .[2].viewsCursor == "views-page-2" and
  .[2].workflowsCursor == "workflows-page-2"
' "$SNAPSHOT_LOG" >/dev/null || \
  fail "snapshot did not exercise independent pagination cursors"

NESTED_SNAPSHOT_OUTPUT="$TEMP_DIR/nested-snapshot.json"
NESTED_SNAPSHOT_LOG="$TEMP_DIR/nested-snapshot.log"
run_capture "$TEMP_DIR/nested-stdout" "$TEMP_DIR/nested-stderr" env \
  PATH="$TEMP_DIR/bin:$PATH" GH_DOUBLE_MODE=nested-pagination \
  GH_DOUBLE_LOG="$NESTED_SNAPSHOT_LOG" GH_DOUBLE_FIXTURE="$RAW" \
  "$BASH" "$SCRIPT" snapshot --owner octo --number 15 \
  --output "$NESTED_SNAPSHOT_OUTPUT"
[[ "$COMMAND_STATUS" -ne 0 ]] || \
  fail "nested pagination should be rejected"
[[ ! -s "$TEMP_DIR/nested-stdout" ]] || \
  fail "nested pagination produced a partial snapshot"
[[ ! -e "$NESTED_SNAPSHOT_OUTPUT" || ! -s "$NESTED_SNAPSHOT_OUTPUT" ]] || \
  fail "nested pagination wrote a partial snapshot file"
[[ "$(<"$TEMP_DIR/nested-stderr")" == \
  "error: snapshot is incomplete: a nested view connection has another page" ]] || \
  fail "nested pagination produced the wrong diagnostic: $(<"$TEMP_DIR/nested-stderr")"

ADOPTION_RAW="$TEMP_DIR/adoption-pristine.json"
ADOPTION_LOG="$TEMP_DIR/adoption.log"
ADOPTION_README='Existing project notes
'
EXPECTED_ADOPTION_README="Existing project notes"$'\n\n'"$MARKER"
jq --arg readme "$ADOPTION_README" '.project.readme = $readme' "$RAW" \
  >"$ADOPTION_RAW"
run_capture "$TEMP_DIR/adoption-stdout" "$TEMP_DIR/adoption-stderr" env \
  PATH="$TEMP_DIR/bin:$PATH" GH_DOUBLE_MODE=adopt \
  GH_DOUBLE_LOG="$ADOPTION_LOG" GH_DOUBLE_FIXTURE="$ADOPTION_RAW" \
  "$BASH" "$SCRIPT" adopt --owner octo --number 15 \
  --repository "$REPOSITORY" --contract "$CONTRACT"
[[ "$COMMAND_STATUS" -eq 0 ]] || \
  fail "adoption of a pristine project should succeed"
jq -S -n -e --arg marker "$MARKER" \
  --slurpfile result "$TEMP_DIR/adoption-stdout" \
  '$result == [{adopted: true, contractVersion: "kanban-v1", marker: $marker}]' \
  >/dev/null || \
  fail "adoption returned the wrong success result"
jq -s -e --arg expected "$EXPECTED_ADOPTION_README" '
  length == 4 and
  .[0].kind == "project-id" and .[0].owner == "octo" and .[0].number == "15" and
  .[1].kind == "snapshot" and
  .[1].id == "project-fixture" and
  .[2].kind == "snapshot" and
  .[2].id == "project-fixture" and
  .[3].kind == "edit" and
  .[3].owner == "octo" and .[3].number == "15" and
  .[3].readme == $expected
' "$ADOPTION_LOG" >/dev/null || \
  fail "adoption did not preserve the README and perform one edit"

REJECTED_ADOPTION_RAW="$TEMP_DIR/adoption-rejected.json"
REJECTED_ADOPTION_LOG="$TEMP_DIR/adoption-rejected.log"
jq '.fields |= map(
  if .name == "Estimate" then .dataType = "DATE" else . end
)' "$RAW" >"$REJECTED_ADOPTION_RAW"
run_capture "$TEMP_DIR/rejected-adoption-stdout" \
  "$TEMP_DIR/rejected-adoption-stderr" env \
  PATH="$TEMP_DIR/bin:$PATH" GH_DOUBLE_MODE=rejected-adopt \
  GH_DOUBLE_LOG="$REJECTED_ADOPTION_LOG" \
  GH_DOUBLE_FIXTURE="$REJECTED_ADOPTION_RAW" "$BASH" "$SCRIPT" adopt \
  --owner octo --number 15 --repository "$REPOSITORY" \
  --contract "$CONTRACT"
[[ "$COMMAND_STATUS" -ne 0 ]] || \
  fail "adoption of a structurally invalid project should fail"
[[ ! -s "$TEMP_DIR/rejected-adoption-stdout" ]] || \
  fail "rejected adoption exposed a verification result to the caller"
[[ "$(<"$TEMP_DIR/rejected-adoption-stderr")" == \
  "error: project is not an unmarked pristine Kanban project" ]] || \
  fail "rejected adoption produced the wrong diagnostic"
jq -s -e '
  length == 3 and
  all(.[]; .kind != "edit")
' "$REJECTED_ADOPTION_LOG" >/dev/null || \
  fail "rejected adoption edited the project"

printf 'project contract tests passed\n'
