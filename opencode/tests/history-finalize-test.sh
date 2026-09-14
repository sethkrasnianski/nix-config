#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

git init --bare --initial-branch=main "$TMP/remote.git" >/dev/null
git clone "$TMP/remote.git" "$TMP/repo" >/dev/null
git -C "$TMP/repo" config user.name test
git -C "$TMP/repo" config user.email test@example.com
printf 'base\n' > "$TMP/repo/file"
git -C "$TMP/repo" add file
git -C "$TMP/repo" commit -m 'chore: base' >/dev/null
git -C "$TMP/repo" push -u origin main >/dev/null

run_finalizer() { (cd "$TMP/repo" && "$ROOT/scripts/history-finalize.sh" "$@"); }

state_value() {
  local wanted="$1" key value
  while IFS='=' read -r key value; do
    if [ "$key" = "$wanted" ]; then
      printf '%s' "$value"
      return 0
    fi
  done <<< "$state"
  return 1
}

for branch in feat/versioned-lifecycle-contract feature/test; do
  git -C "$TMP/repo" checkout -b "$branch" origin/main >/dev/null
  subject="chore: bootstrap $branch"
  if [ "$branch" = feat/versioned-lifecycle-contract ]; then
    subject='chore: bootstrap versioned lifecycle contract'
  fi
  git -C "$TMP/repo" commit --allow-empty -m "$subject" >/dev/null
  git -C "$TMP/repo" push -u origin "$branch" >/dev/null
  bootstrap_sha="$(git -C "$TMP/repo" rev-parse HEAD)"
  printf 'change\n' >> "$TMP/repo/file"
  git -C "$TMP/repo" add file
  git -C "$TMP/repo" commit -m 'feat: add change' >/dev/null
  git -C "$TMP/repo" commit --allow-empty -m 'chore: preserve empty' >/dev/null
  printf 'another change\n' > "$TMP/repo/another-file"
  git -C "$TMP/repo" add another-file
  git -C "$TMP/repo" commit -m 'feat: another change' >/dev/null
  old_head="$(git -C "$TMP/repo" rev-parse HEAD)"
  old_tree="$(git -C "$TMP/repo" rev-parse 'HEAD^{tree}')"

  # shellcheck disable=SC2016 # The test command is evaluated in the disposable repo.
  run_finalizer prepare --base main --test 'test "$(cat file)" = "$(printf "base\nchange")" && touch .git/prepare-test-ran' >/dev/null
  [ -f "$TMP/repo/.git/prepare-test-ran" ]
  [ "$(git -C "$TMP/repo" rev-parse 'HEAD^{tree}')" = "$old_tree" ]
  [ "$(git --git-dir="$TMP/remote.git" rev-parse "$branch")" = "$bootstrap_sha" ]
  log="$(git -C "$TMP/repo" log --format=%s origin/main..HEAD)"
  case "$log" in *'bootstrap'*) printf 'bootstrap survived prepare\n' >&2; exit 1;; esac
  case "$log" in *'feat: add change'*) :;; *) exit 1;; esac
  case "$log" in *'preserve empty'*) :;; *) exit 1;; esac
  [ "$(git -C "$TMP/repo" rev-list --count origin/main..HEAD)" = 3 ]
  state="$(run_finalizer status)"
  head_sha="$(state_value new_head)"
  remote_sha="$(state_value remote_sha)"
  [ "$remote_sha" = "$bootstrap_sha" ]
  [ "$(state_value old_head)" = "$old_head" ]
  [ "$(state_value test_result)" = passed ]
  [ "$(git -C "$TMP/repo" rev-parse "$(state_value recovery_ref)")" = "$old_head" ]
  run_finalizer publish --base main --head "$head_sha" --remote "$remote_sha" >/dev/null
  [ "$(git --git-dir="$TMP/remote.git" rev-parse "$branch")" = "$head_sha" ]
  rm "$TMP/repo/.git/prepare-test-ran"
done

for scenario in contentful preceding-change duplicate; do
  branch="feature/$scenario"
  git -C "$TMP/repo" checkout -b "$branch" origin/main >/dev/null
  expected_error='bootstrap must be an empty first commit'
  if [ "$scenario" = duplicate ]; then
    git -C "$TMP/repo" commit --allow-empty -m "chore: bootstrap $branch" >/dev/null
    expected_error='ambiguous bootstrap commits'
  fi
  printf 'must survive\n' >> "$TMP/repo/file"
  git -C "$TMP/repo" add file
  if [ "$scenario" != contentful ]; then
    git -C "$TMP/repo" commit -m 'feat: earlier change' >/dev/null
  fi
  git -C "$TMP/repo" commit --allow-empty -m 'chore: bootstrap versioned lifecycle contract' >/dev/null
  git -C "$TMP/repo" push -u origin "$branch" >/dev/null
  old_head="$(git -C "$TMP/repo" rev-parse HEAD)"
  if run_finalizer prepare --base main --test 'touch .git/unsafe-test-ran' >"$TMP/rejected" 2>&1; then
    printf 'unsafe bootstrap accepted: %s\n' "$scenario" >&2
    exit 1
  fi
  grep -q "$expected_error" "$TMP/rejected"
  [ "$(git -C "$TMP/repo" rev-parse HEAD)" = "$old_head" ]
  [ "$(git --git-dir="$TMP/remote.git" rev-parse "$branch")" = "$old_head" ]
  [ ! -f "$TMP/repo/.git/unsafe-test-ran" ]
  [ "$(run_finalizer status)" = status=none ]
done

printf 'history-finalize tests passed\n'
