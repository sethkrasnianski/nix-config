#!/usr/bin/env bash
# auto-history-finalize -- guarded local history rewrite and explicit publish.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  auto-history-finalize prepare --base BRANCH --test COMMAND
  auto-history-finalize publish --base BRANCH --head SHA --remote SHA
  auto-history-finalize status
EOF
}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

require_clean_tree() {
  git diff --quiet || die "working tree has unstaged changes"
  git diff --cached --quiet || die "working tree has staged changes"
  [ -z "$(git status --porcelain --untracked-files=all)" ] || die "working tree has untracked changes"
}

require_no_operation() {
  local git_dir
  git_dir="$(git rev-parse --git-dir)"
  [ ! -e "$git_dir/rebase-merge" ] && [ ! -e "$git_dir/rebase-apply" ] || die "a rebase is already in progress"
  [ ! -e "$git_dir/MERGE_HEAD" ] || die "a merge is already in progress"
  [ ! -e "$git_dir/CHERRY_PICK_HEAD" ] || die "a cherry-pick is already in progress"
}

state_dir() {
  local common branch
  common="$(git rev-parse --git-common-dir)"
  branch="$(git branch --show-current)"
  printf '%s/auto-agent/history-finalize/%s' "$common" "${branch//\//--}"
}

with_lock() {
  local lock="$1"; shift
  if ! mkdir "$lock" 2>/dev/null; then
    die "history mutation lock is held: $lock"
  fi
  trap "rmdir '$lock' 2>/dev/null || true" EXIT INT TERM
  "$@"
}

require_branch_and_upstream() {
  BRANCH="$(git branch --show-current)"
  [ -n "$BRANCH" ] || die "HEAD is detached"
  [ "$BRANCH" != "$BASE" ] || die "refusing to finalize the base branch"
  UPSTREAM="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)" || die "branch has no upstream"
  [ "$UPSTREAM" = "origin/$BRANCH" ] || die "upstream must be exactly origin/$BRANCH (found $UPSTREAM)"
}

authoritative_remote_sha() {
  git ls-remote --exit-code origin "refs/heads/$BRANCH" | while read -r sha _; do printf '%s\n' "$sha"; break; done
}

write_state() {
  local dir="$1"
  shift
  mkdir -p "$dir"
  : > "$dir/state"
  while [ "$#" -gt 1 ]; do
    printf '%s=%s\n' "$1" "$2" >> "$dir/state"
    shift 2
  done
}

read_state() {
  local key="$1" file="$2"
  [ -f "$file" ] || die "no prepared finalization state"
  while IFS='=' read -r state_key state_value; do
    [ "$state_key" = "$key" ] && { printf '%s\n' "$state_value"; return 0; }
  done < "$file"
  die "prepared state is missing $key"
}

prepare_locked() {
  require_clean_tree
  require_no_operation
  require_branch_and_upstream
  git fetch --prune origin "$BASE" "$BRANCH"
  BASE_SHA="$(git rev-parse "origin/$BASE")"
  REMOTE_SHA="$(authoritative_remote_sha)" || die "remote branch origin/$BRANCH does not exist"
  [ "$(git rev-parse "$UPSTREAM")" = "$REMOTE_SHA" ] || die "local upstream is stale; fetch and retry"
  OLD_HEAD="$(git rev-parse HEAD)"
  RECOVERY_REF="refs/auto-agent/recovery/${BRANCH//\//--}/$(date -u +%Y%m%d%H%M%S)"
  git update-ref "$RECOVERY_REF" "$OLD_HEAD"
  git rebase "$BASE_SHA"
  BOOTSTRAP_SHA="$(git log --reverse --format=%H --grep="^chore: bootstrap $BRANCH$" "$BASE_SHA..HEAD" | head -n 1 || true)"
  if [ -n "$BOOTSTRAP_SHA" ]; then
    # The bootstrap commit is known harness metadata. Replaying its descendants
    # drops only that commit and preserves intentional empty commits.
    git rebase --onto "$BASE_SHA" "$BOOTSTRAP_SHA"
    GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash "$BASE_SHA"
  else
    GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash "$BASE_SHA"
  fi
  NEW_HEAD="$(git rev-parse HEAD)"
  bash -lc "$TEST_COMMAND"
  write_state "$STATE_DIR" base "$BASE" base_sha "$BASE_SHA" old_head "$OLD_HEAD" new_head "$NEW_HEAD" remote_sha "$REMOTE_SHA" recovery_ref "$RECOVERY_REF" test "$TEST_COMMAND" test_result passed
  printf 'prepared base=%s base_sha=%s old_head=%s new_head=%s remote_sha=%s recovery_ref=%s test=passed\n' "$BASE" "$BASE_SHA" "$OLD_HEAD" "$NEW_HEAD" "$REMOTE_SHA" "$RECOVERY_REF"
  git log --oneline "$BASE_SHA..$NEW_HEAD"
}

cmd_prepare() {
  BASE="" TEST_COMMAND=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --base) BASE="${2:-}"; shift 2 ;;
      --test) TEST_COMMAND="${2:-}"; shift 2 ;;
      *) die "unknown argument: $1" ;;
    esac
  done
  [ -n "$BASE" ] && [ -n "$TEST_COMMAND" ] || die "prepare requires --base and --test"
  STATE_DIR="$(state_dir)"
  mkdir -p "$(dirname "$STATE_DIR")"
  with_lock "${STATE_DIR}.lock" prepare_locked
}

publish_locked() {
  require_clean_tree
  require_no_operation
  require_branch_and_upstream
  local state="$STATE_DIR/state" prepared_base prepared_head prepared_remote current_remote
  prepared_base="$(read_state base "$state")"
  prepared_head="$(read_state new_head "$state")"
  prepared_remote="$(read_state remote_sha "$state")"
  [ "$prepared_base" = "$BASE" ] || die "base changed since preview"
  [ "$HEAD_SHA" = "$prepared_head" ] || die "provided head does not match preview"
  [ "$REMOTE_SHA" = "$prepared_remote" ] || die "provided remote SHA does not match preview"
  [ "$(git rev-parse HEAD)" = "$prepared_head" ] || die "HEAD changed since preview"
  current_remote="$(authoritative_remote_sha)" || die "remote branch no longer exists"
  [ "$current_remote" = "$prepared_remote" ] || die "remote branch changed since preview"
  git push origin "HEAD:refs/heads/$BRANCH" --force-with-lease="refs/heads/$BRANCH:$prepared_remote"
  [ "$(authoritative_remote_sha)" = "$prepared_head" ] || die "remote did not reach expected HEAD"
  printf 'published branch=%s head=%s\n' "$BRANCH" "$prepared_head"
}

cmd_publish() {
  BASE="" HEAD_SHA="" REMOTE_SHA=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --base) BASE="${2:-}"; shift 2 ;;
      --head) HEAD_SHA="${2:-}"; shift 2 ;;
      --remote) REMOTE_SHA="${2:-}"; shift 2 ;;
      *) die "unknown argument: $1" ;;
    esac
  done
  [ -n "$BASE" ] && [ -n "$HEAD_SHA" ] && [ -n "$REMOTE_SHA" ] || die "publish requires --base, --head, and --remote"
  STATE_DIR="$(state_dir)"
  mkdir -p "$(dirname "$STATE_DIR")"
  with_lock "${STATE_DIR}.lock" publish_locked
}

cmd_status() {
  STATE_DIR="$(state_dir)"
  [ -f "$STATE_DIR/state" ] || { printf 'status=none\n'; return; }
  printf 'status=prepared\n'
  cat "$STATE_DIR/state"
}

case "${1:-}" in
  prepare) shift; cmd_prepare "$@" ;;
  publish) shift; cmd_publish "$@" ;;
  status) shift; cmd_status "$@" ;;
  *) usage; exit 1 ;;
esac
