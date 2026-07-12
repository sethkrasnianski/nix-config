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
git -C "$TMP/repo" checkout -b feature/test >/dev/null
git -C "$TMP/repo" commit --allow-empty -m 'chore: bootstrap feature/test' >/dev/null
printf 'change\n' >> "$TMP/repo/file"
git -C "$TMP/repo" add file
git -C "$TMP/repo" commit -m 'feat: add change' >/dev/null
git -C "$TMP/repo" commit --allow-empty -m 'chore: preserve empty' >/dev/null
git -C "$TMP/repo" push -u origin feature/test >/dev/null

run_finalizer() { (cd "$TMP/repo" && "$ROOT/scripts/history-finalize.sh" "$@"); }

run_finalizer prepare --base main --test true >/dev/null
log="$(git -C "$TMP/repo" log --format=%s origin/main..HEAD)"
case "$log" in *'bootstrap'*) exit 1;; esac
case "$log" in *'preserve empty'*) :;; *) exit 1;; esac
state="$(run_finalizer status)"
state_value() {
  local wanted="$1" key value
  while IFS== read -r key value; do
    if [ "$key" = "$wanted" ]; then
      printf '%s' "$value"
      return 0
    fi
  done <<< "$state"
  return 1
}
head_sha="$(state_value new_head)"
remote_sha="$(state_value remote_sha)"
run_finalizer publish --base main --head "$head_sha" --remote "$remote_sha" >/dev/null
[ "$(git --git-dir="$TMP/remote.git" rev-parse feature/test)" = "$head_sha" ]

printf 'history-finalize tests passed\n'
