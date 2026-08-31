#!/usr/bin/env bash
set -euo pipefail

# Snapshot and verify the API-visible contract of a GitHub Projects V2 Kanban
# project. The verifier deliberately knows nothing about template provenance:
# a pristine structure is accepted once, and an adopted project must carry the
# marker written by this script.
# GraphQL variables intentionally contain literal dollar signs.
# shellcheck disable=SC2016

readonly CONTRACT_VERSION="kanban-v1"
readonly MARKER="<!-- github-projects-tickets: ${CONTRACT_VERSION} -->"
readonly MARKER_PREFIX="<!-- github-projects-tickets:"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat >&2 <<'EOF'
usage:
  project-contract.sh snapshot --owner LOGIN --number NUMBER --output FILE
  project-contract.sh normalize --input FILE [--output FILE]
  project-contract.sh capture-contract --snapshot FILE --output FILE
  project-contract.sh verify --contract FILE --snapshot FILE [--repository OWNER/REPO]
  project-contract.sh adopt --owner LOGIN --number NUMBER --repository OWNER/REPO --contract FILE
EOF
  exit 2
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

require_file() {
  [[ -f "$1" ]] || die "file not found: $1"
}

write_output() {
  local content="$1" output="$2"

  if [[ "$output" == "-" ]]; then
    printf '%s\n' "$content"
  else
    printf '%s\n' "$content" >"$output"
  fi
}

graphql_error_free() {
  jq -e '((.errors // []) | length) == 0' >/dev/null || {
    jq -r '(.errors // [])[] | .message' >&2
    return 1
  }
}

project_id() {
  local owner="$1" number="$2" response query

  # shellcheck disable=SC2016
  query='query($login:String!, $number:Int!) {
    repositoryOwner(login:$login) {
      ... on Organization { projectV2(number:$number) { id } }
      ... on User { projectV2(number:$number) { id } }
    }
  }'

  if ! response="$(gh api graphql -f query="$query" -f login="$owner" -F number="$number")"; then
    die "unable to query project ${owner}/${number}"
  fi
  printf '%s\n' "$response" | graphql_error_free || die "GitHub rejected the project query"
  printf '%s\n' "$response" | jq -er '.data.repositoryOwner.projectV2.id // empty' \
    || die "project ${owner}/${number} was not found or is not visible"
}

snapshot_project() {
  local owner="$1" number="$2" output="$3" id query response
  local repositories_cursor='' fields_cursor='' views_cursor='' workflows_cursor=''
  local repositories='[]' fields='[]' views='[]' workflows='[]' project='null'
  local repositories_done=false fields_done=false views_done=false workflows_done=false
  local -a args

  id="$(project_id "$owner" "$number")"

  # shellcheck disable=SC2016
  query='fragment fieldConfiguration on ProjectV2FieldConfiguration {
    ... on ProjectV2Field {
      __typename id name dataType isIssueField
    }
    ... on ProjectV2SingleSelectField {
      __typename id name dataType isIssueField
      options { id name color description }
    }
    ... on ProjectV2MultiSelectField {
      __typename id name dataType isIssueField
      multiSelectOptions { id name color description }
    }
    ... on ProjectV2IterationField {
      __typename id name dataType isIssueField
      configuration {
        startDay duration
        iterations { id title startDate duration }
        completedIterations { id title startDate duration }
      }
    }
  }

  query($id:ID!, $repositoriesCursor:String, $fieldsCursor:String,
        $viewsCursor:String, $workflowsCursor:String) {
    node(id:$id) {
      ... on ProjectV2 {
        id number title template shortDescription readme public closed
        repositories(first:100, after:$repositoriesCursor) {
          nodes { id nameWithOwner }
          pageInfo { hasNextPage endCursor }
        }
        fields(first:100, after:$fieldsCursor) {
          nodes { ...fieldConfiguration }
          pageInfo { hasNextPage endCursor }
        }
        views(first:100, after:$viewsCursor) {
          nodes {
            id number name layout filter
            fields(first:100) {
              nodes { ...fieldConfiguration }
              pageInfo { hasNextPage endCursor }
            }
            configuration {
              visibleFields(first:100) {
                nodes { ...fieldConfiguration }
                pageInfo { hasNextPage endCursor }
              }
            }
            groupByFields(first:100) {
              nodes { ...fieldConfiguration }
              pageInfo { hasNextPage endCursor }
            }
            sortByFields(first:100) {
              nodes {
                direction
                field { ...fieldConfiguration }
              }
              pageInfo { hasNextPage endCursor }
            }
            verticalGroupByFields(first:100) {
              nodes { ...fieldConfiguration }
              pageInfo { hasNextPage endCursor }
            }
          }
          pageInfo { hasNextPage endCursor }
        }
        workflows(first:100, after:$workflowsCursor) {
          nodes { id number name enabled }
          pageInfo { hasNextPage endCursor }
        }
      }
    }
  }'

  while [[ "$repositories_done" == false || "$fields_done" == false || \
    "$views_done" == false || "$workflows_done" == false ]]; do
    args=(-f query="$query" -F id="$id")
    [[ -n "$repositories_cursor" ]] && args+=(-f repositoriesCursor="$repositories_cursor")
    [[ -n "$fields_cursor" ]] && args+=(-f fieldsCursor="$fields_cursor")
    [[ -n "$views_cursor" ]] && args+=(-f viewsCursor="$views_cursor")
    [[ -n "$workflows_cursor" ]] && args+=(-f workflowsCursor="$workflows_cursor")

    if ! response="$(gh api graphql "${args[@]}")"; then
      die "unable to snapshot project ${owner}/${number}"
    fi
    printf '%s\n' "$response" | graphql_error_free || die "GitHub rejected the project snapshot query"
    jq -e '.data.node != null' >/dev/null <<<"$response" || die "project disappeared during snapshot"

    project="$(jq -c '.data.node | del(.repositories, .fields, .views, .workflows)' <<<"$response")"
    repositories="$(jq -c --argjson old "$repositories" \
      '$old + (.data.node.repositories.nodes // []) | unique_by(.id)' <<<"$response")"
    fields="$(jq -c --argjson old "$fields" \
      '$old + (.data.node.fields.nodes // []) | unique_by(.id)' <<<"$response")"
    views="$(jq -c --argjson old "$views" \
      '$old + (.data.node.views.nodes // []) | unique_by(.id)' <<<"$response")"
    workflows="$(jq -c --argjson old "$workflows" \
      '$old + (.data.node.workflows.nodes // []) | unique_by(.id)' <<<"$response")"

    if [[ "$repositories_done" == false ]]; then
      if [[ "$(jq -r '.data.node.repositories.pageInfo.hasNextPage' <<<"$response")" == true ]]; then
        repositories_cursor="$(jq -er '.data.node.repositories.pageInfo.endCursor' <<<"$response")"
      else
        repositories_done=true
      fi
    fi
    if [[ "$fields_done" == false ]]; then
      if [[ "$(jq -r '.data.node.fields.pageInfo.hasNextPage' <<<"$response")" == true ]]; then
        fields_cursor="$(jq -er '.data.node.fields.pageInfo.endCursor' <<<"$response")"
      else
        fields_done=true
      fi
    fi
    if [[ "$views_done" == false ]]; then
      if [[ "$(jq -r '.data.node.views.pageInfo.hasNextPage' <<<"$response")" == true ]]; then
        views_cursor="$(jq -er '.data.node.views.pageInfo.endCursor' <<<"$response")"
      else
        views_done=true
      fi
    fi
    if [[ "$workflows_done" == false ]]; then
      if [[ "$(jq -r '.data.node.workflows.pageInfo.hasNextPage' <<<"$response")" == true ]]; then
        workflows_cursor="$(jq -er '.data.node.workflows.pageInfo.endCursor' <<<"$response")"
      else
        workflows_done=true
      fi
    fi

    # Nested view connections cannot share the top-level cursors. A page with
    # more than 100 nested entries is rejected rather than partially compared.
    if jq -e '
      [.data.node.views.nodes[] |
       (.fields.pageInfo.hasNextPage // false),
       (.configuration.visibleFields.pageInfo.hasNextPage // false),
       (.groupByFields.pageInfo.hasNextPage // false),
       (.sortByFields.pageInfo.hasNextPage // false),
       (.verticalGroupByFields.pageInfo.hasNextPage // false)]
       | any(. == true)' >/dev/null <<<"$response"; then
      die "snapshot is incomplete: a nested view connection has another page"
    fi
  done

  local snapshot
  snapshot="$(jq -S -n \
    --argjson project "$project" \
    --argjson repositories "$repositories" \
    --argjson fields "$fields" \
    --argjson views "$views" \
    --argjson workflows "$workflows" \
    '{schemaVersion: 1, pagination: {complete: true}, project: $project,
      repositories: $repositories, fields: $fields, views: $views,
      workflows: $workflows}')"
  write_output "$snapshot" "$output"
}

normalize_snapshot() {
  local input="$1" output="$2" normalized
  require_file "$input"

  normalized="$(jq -S --arg contract_version "$CONTRACT_VERSION" \
    --arg marker "$MARKER" --arg marker_prefix "$MARKER_PREFIX" '
    def require_array($name):
      if (.[$name] | type) == "array" then .
      else error(($name + " must be an array")) end;
    def option:
      {name: (.name // ""), color: (.color // ""),
       description: (.description // "")};
    def iteration_field:
      {kind: "iteration", name: (.name // ""),
       dataType: (.dataType // null), isIssueField: (.isIssueField // false)};
    def field:
      if .__typename == "ProjectV2SingleSelectField" then
        {kind: "single-select", name: (.name // ""),
         dataType: (.dataType // null), isIssueField: (.isIssueField // false),
         options: ([.options // [] | .[] | option] | sort_by(.name))}
      elif .__typename == "ProjectV2MultiSelectField" then
        {kind: "multi-select", name: (.name // ""),
         dataType: (.dataType // null), isIssueField: (.isIssueField // false),
         options: ([.multiSelectOptions // [] | .[] | option] | sort_by(.name))}
      elif .__typename == "ProjectV2IterationField" then
        iteration_field
      elif .__typename == "ProjectV2Field" then
        {kind: "field", name: (.name // ""),
         dataType: (.dataType // null), isIssueField: (.isIssueField // false)}
      else
        error("unknown project field type: " + (.__typename // "null"))
      end;
    def field_list($nodes):
      [$nodes // [] | .[] | field]
      | sort_by([.name, .kind, (.dataType // "")]);
    def view_fields:
      ([.fields.nodes // []] + [.configuration.visibleFields.nodes // []])
      | add | unique_by(.id // (.name + (.__typename // ""))) | field_list(.);
    def group_fields:
      field_list(.groupByFields.nodes // []);
    def vertical_group_fields:
      field_list(.verticalGroupByFields.nodes // []);
    def sort_fields:
      [.sortByFields.nodes // [] | .[] |
       {field: (.field.name // ""), direction: (.direction // "")}]
      | sort_by([.field, .direction]);
    def view:
      {name: (.name // ""), layout: (.layout // ""), filter: (.filter // ""),
       fields: view_fields, groupByFields: group_fields,
       sortByFields: sort_fields, verticalGroupByFields: vertical_group_fields};
    def markers:
      [(.project.readme // "") | scan($marker_prefix + "[^>]*-->")];

    if (.schemaVersion // 0) != 1 then
      error("unsupported snapshot schema")
    elif (.pagination.complete // false) != true then
      error("snapshot pagination is incomplete")
    elif (.project | type) != "object" then
      error("project must be an object")
    else
      require_array("fields")
      | require_array("views")
      | require_array("workflows")
      | (markers) as $markers
      | {contractVersion: $contract_version,
         marker: {count: ($markers | length), values: $markers,
                  valid: ($markers == [$marker])},
         fields: ([.fields[] | field]
                  | sort_by([.name, .kind, (.dataType // "")])),
         views: ([.views[] | view] | sort_by([.name, .layout])),
         workflows: ([.workflows[] |
                      {name: (.name // ""), enabled: (.enabled // false)}]
                     | sort_by(.name))}
    end
  ' "$input")" || die "unable to normalize snapshot: $input"

  write_output "$normalized" "$output"
}

capture_contract() {
  local snapshot="$1" output="$2" normalized contract
  jq -e '.project.template == false and .project.closed == false' "$snapshot" >/dev/null \
    || die "only an active project instance can become a contract"
  normalized="$(normalize_snapshot "$snapshot" -)"

  jq -e --arg marker "$MARKER" '
    .marker.count == 0 and (.marker.values | length) == 0
  ' >/dev/null <<<"$normalized" || die "only an unmarked snapshot can become a contract"

  contract="$(jq -S 'del(.marker)' <<<"$normalized")"
  write_output "$contract" "$output"
}

verify_snapshot() {
  local contract_file="$1" snapshot="$2" repository="$3" contract candidate result
  require_file "$contract_file"
  contract="$(jq -S --arg version "$CONTRACT_VERSION" '
    if .contractVersion != $version then
      error("contract version must be " + $version)
    elif .status? == "pending-canonical-capture" then
      error("the canonical contract has not been captured")
    elif (.fields | type) != "array" or (.views | type) != "array" or
         (.workflows | type) != "array" then
      error("contract has an invalid shape")
    else . end
  ' "$contract_file")" || die "invalid contract: $contract_file"

  if [[ -n "$repository" ]]; then
    jq -e --arg repository "$repository" \
      '(.repositories | type) == "array" and
       any(.repositories[]; .nameWithOwner == $repository)' \
      "$snapshot" >/dev/null || die "project is not linked to repository $repository"
  fi

  jq -e '.project.template == false' "$snapshot" >/dev/null \
    || die "organization project templates cannot be used as ticket boards"
  jq -e '.project.closed == false' "$snapshot" >/dev/null \
    || die "closed projects cannot be used as ticket boards"

  candidate="$(normalize_snapshot "$snapshot" -)"
  result="$(jq -S -n \
    --arg marker "$MARKER" \
    --argjson contract "$contract" \
    --argjson candidate "$candidate" '
      def structure:
        {fields: .fields, views: .views, workflows: .workflows};
      def contains_all($required; $actual):
        all($required[]; . as $item | any($actual[]; . == $item));
      def preserves($required; $actual):
        contains_all($required; $actual) and
        all($actual[]; . as $item |
            all($required[]; (.name != $item.name or . == $item)));
      def baseline_matches:
        preserves($contract.fields; $candidate.fields) and
        preserves($contract.views; $candidate.views) and
        ($candidate.workflows == $contract.workflows);
      if ($candidate.marker.count == 0) and
         (($candidate | structure) == ($contract | structure)) then
        {valid: true, mode: "pristine", contractVersion: $contract.contractVersion}
      elif ($candidate.marker.values == [$marker]) and baseline_matches then
        {valid: true, mode: "marked-superset", contractVersion: $contract.contractVersion}
      else
        {valid: false, mode: "rejected", contractVersion: $contract.contractVersion}
      end
     ')"

  if [[ "$(jq -r '.valid' <<<"$result")" != true ]]; then
    printf '%s\n' "$result"
    return 1
  fi
  printf '%s\n' "$result"
}

adopt_project() {
  local owner="$1" number="$2" repository="$3" contract_file="$4"
  local snapshot_file result readme new_readme

  ADOPT_TEMP_DIR="$(mktemp -d)"
  trap cleanup_adopt_temp_dir EXIT
  snapshot_file="$ADOPT_TEMP_DIR/project.json"
  snapshot_project "$owner" "$number" "$snapshot_file"
  result="$(verify_snapshot "$contract_file" "$snapshot_file" "$repository")" \
    || die "project is not an unmarked pristine Kanban project"
  [[ "$(jq -r '.mode' <<<"$result")" == pristine ]] || \
    die "adoption requires an unmarked pristine project"

  readme="$(jq -r '.project.readme // ""' "$snapshot_file")"
  if [[ "$readme" == *"$MARKER_PREFIX"* ]]; then
    die "project README already contains a ticket-skill marker"
  elif [[ -n "$readme" ]]; then
    new_readme="${readme%$'\n'}"$'\n\n'"${MARKER}"
  else
    new_readme="$MARKER"
  fi

  gh project edit "$number" --owner "$owner" --readme "$new_readme" >/dev/null \
    || die "unable to append the adoption marker to the project README"
  jq -n --arg version "$CONTRACT_VERSION" --arg marker "$MARKER" \
    '{adopted: true, contractVersion: $version, marker: $marker}'
}

cleanup_adopt_temp_dir() {
  if [[ -n "${ADOPT_TEMP_DIR:-}" ]]; then
    rm -rf -- "$ADOPT_TEMP_DIR"
  fi
}

snapshot_command() {
  local owner='' number='' output=''
  while (($#)); do
    case "$1" in
      --owner) [[ $# -ge 2 ]] || usage; owner="$2"; shift 2 ;;
      --number) [[ $# -ge 2 ]] || usage; number="$2"; shift 2 ;;
      --output) [[ $# -ge 2 ]] || usage; output="$2"; shift 2 ;;
      *) usage ;;
    esac
  done
  [[ -n "$owner" && -n "$number" && -n "$output" ]] || usage
  require_command gh
  require_command jq
  snapshot_project "$owner" "$number" "$output"
}

normalize_command() {
  local input='' output='-'
  while (($#)); do
    case "$1" in
      --input) [[ $# -ge 2 ]] || usage; input="$2"; shift 2 ;;
      --output) [[ $# -ge 2 ]] || usage; output="$2"; shift 2 ;;
      *) usage ;;
    esac
  done
  [[ -n "$input" ]] || usage
  require_command jq
  normalize_snapshot "$input" "$output"
}

capture_command() {
  local snapshot='' output=''
  while (($#)); do
    case "$1" in
      --snapshot) [[ $# -ge 2 ]] || usage; snapshot="$2"; shift 2 ;;
      --output) [[ $# -ge 2 ]] || usage; output="$2"; shift 2 ;;
      *) usage ;;
    esac
  done
  [[ -n "$snapshot" && -n "$output" ]] || usage
  require_command jq
  capture_contract "$snapshot" "$output"
}

verify_command() {
  local contract='' snapshot='' repository=''
  while (($#)); do
    case "$1" in
      --contract) [[ $# -ge 2 ]] || usage; contract="$2"; shift 2 ;;
      --snapshot) [[ $# -ge 2 ]] || usage; snapshot="$2"; shift 2 ;;
      --repository) [[ $# -ge 2 ]] || usage; repository="$2"; shift 2 ;;
      *) usage ;;
    esac
  done
  [[ -n "$contract" && -n "$snapshot" ]] || usage
  require_command jq
  verify_snapshot "$contract" "$snapshot" "$repository"
}

adopt_command() {
  local owner='' number='' repository='' contract=''
  while (($#)); do
    case "$1" in
      --owner) [[ $# -ge 2 ]] || usage; owner="$2"; shift 2 ;;
      --number) [[ $# -ge 2 ]] || usage; number="$2"; shift 2 ;;
      --repository) [[ $# -ge 2 ]] || usage; repository="$2"; shift 2 ;;
      --contract) [[ $# -ge 2 ]] || usage; contract="$2"; shift 2 ;;
      *) usage ;;
    esac
  done
  [[ -n "$owner" && -n "$number" && -n "$repository" && -n "$contract" ]] || usage
  require_command gh
  require_command jq
  adopt_project "$owner" "$number" "$repository" "$contract"
}

main() {
  (($# >= 1)) || usage
  local command="$1"
  shift
  case "$command" in
    snapshot) snapshot_command "$@" ;;
    normalize) normalize_command "$@" ;;
    capture-contract) capture_command "$@" ;;
    verify) verify_command "$@" ;;
    adopt) adopt_command "$@" ;;
    *) usage ;;
  esac
}

main "$@"
