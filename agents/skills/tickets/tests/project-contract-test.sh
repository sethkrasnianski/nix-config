#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/project-contract.sh"
CONTRACT="$ROOT/fixtures/kanban-v1.contract.json"
REPOSITORY="octo/example"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

fail() {
  printf 'failure: %s\n' "$*" >&2
  exit 1
}

assert_mode() {
  local snapshot="$1" expected="$2" result
  result="$(bash "$SCRIPT" verify --contract "$CONTRACT" --snapshot "$ROOT/fixtures/$snapshot" --repository "$REPOSITORY")" \
    || fail "$snapshot should be accepted"
  [[ "$(jq -r '.valid' <<<"$result")" == true ]] || fail "$snapshot was not valid"
  [[ "$(jq -r '.mode' <<<"$result")" == "$expected" ]] || \
    fail "$snapshot had the wrong verification mode"
}

assert_rejected() {
  local snapshot="$1"
  assert_rejected_file "$ROOT/fixtures/$snapshot"
}

assert_rejected_file() {
  local snapshot="$1"
  if bash "$SCRIPT" verify --contract "$CONTRACT" --snapshot "$snapshot" \
    --repository "$REPOSITORY" >/dev/null 2>&1; then
    fail "$(basename "$snapshot") should be rejected"
  fi
}

assert_mode pristine.json pristine
assert_mode marked-superset.json marked-superset

external_result="$(
  cd "$TEMP_DIR"
  "$SCRIPT" verify --contract "$CONTRACT" \
    --snapshot "$ROOT/fixtures/pristine.json" --repository "$REPOSITORY"
)" || fail "the skill helper should work outside its source repository"
[[ "$(jq -r '.mode' <<<"$external_result")" == pristine ]] || \
  fail "external-directory verification returned the wrong mode"

assert_rejected missing-status.json
assert_rejected missing-status-option.json
assert_rejected customized-unmarked.json
assert_rejected unrelated.json
assert_rejected malformed-marker.json
assert_rejected incomplete-pagination.json

jq '(.fields[] | select(.name == "Status").options[] |
    select(.name == "In Progress").color) = "RED"' \
  "$ROOT/fixtures/marked-superset.json" >"$TEMP_DIR/altered-marked.json"
assert_rejected_file "$TEMP_DIR/altered-marked.json"

jq '.workflows += [{"name": "Unexpected workflow", "enabled": true}]' \
  "$ROOT/fixtures/marked-superset.json" >"$TEMP_DIR/extra-workflow.json"
assert_rejected_file "$TEMP_DIR/extra-workflow.json"

if bash "$SCRIPT" verify --contract "$CONTRACT" --snapshot "$ROOT/fixtures/pristine.json" \
  --repository octo/not-the-repository >/dev/null 2>&1; then
  fail "a project linked to another repository should be rejected"
fi

bash "$SCRIPT" capture-contract --snapshot "$ROOT/fixtures/pristine.json" \
  --output "$TEMP_DIR/captured.json"
  jq -n -e --slurpfile captured "$TEMP_DIR/captured.json" \
  --slurpfile expected "$CONTRACT" '$captured[0] == $expected[0]' >/dev/null \
  || fail "capture-contract did not produce the expected normalized contract"

if bash "$SCRIPT" verify --contract "$ROOT/contracts/kanban-v1.json" \
  --snapshot "$ROOT/fixtures/pristine.json" >/dev/null 2>&1; then
  fail "the uncaptured production contract should fail closed"
fi

printf 'project contract tests passed\n'
