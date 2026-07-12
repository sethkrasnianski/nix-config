#!/usr/bin/env bash
#
# auto-pr-watch — background rebase watcher for auto-agent PR branches.
#
# Periodically fetches the base branch and, if the current branch has
# fallen behind, rebases onto it and force-with-lease pushes. On an
# unresolvable conflict it aborts the rebase (leaving the working tree
# clean), drops a `.auto/NEEDS_REBASE` marker, comments once on the PR,
# and keeps retrying on its normal interval (a later manual push clears
# the marker automatically). It exits on its own once the PR is no longer
# open (merged or closed).
#
# This script never resolves conflicts itself — that's the interactive
# `resolve-merge-conflicts` skill's job. It also never touches any branch
# other than the one it was started for for, and never merges.
#
# Dependencies: bash, git, gh. Nothing else.
#
# Usage:
#   auto-pr-watch start <branch> [--interval SECONDS] [--base BRANCH]
#   auto-pr-watch stop <branch>
#   auto-pr-watch status <branch>
#
# `start` must be run with cwd inside the worktree checked out to <branch>.
# `stop`/`status` can be run from anywhere, identified by branch name alone.

set -u -o pipefail

STATE_ROOT="${AUTO_PR_WATCH_STATE_DIR:-$HOME/.local/state/auto-agent/pr-watch}"
DEFAULT_INTERVAL=300 # 5 minutes

log() {
  # Timestamped log line. When called from the daemon this goes to the
  # worktree's .auto/pr-watch.log (via the daemon's own stdout redirect);
  # when called from start/stop/status it goes straight to the terminal.
  printf '%s %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"
}

die() {
  log "error: $*" >&2
  exit 1
}

sanitize_branch() {
  # Turn "feat/my-slug" into "feat--my-slug" for use as a directory name.
  printf '%s' "${1//\//--}"
}

state_dir_for() {
  local repo_key
  repo_key="$(git rev-parse --git-common-dir 2>/dev/null | tr '/ ' '__' || printf 'unknown-repo')"
  printf '%s/%s/%s' "$STATE_ROOT" "$repo_key" "$(sanitize_branch "$1")"
}

is_running() {
  # $1 = pid file path. Returns 0 (true) if that pid is alive.
  local pidfile="$1"
  [ -f "$pidfile" ] || return 1
  local pid
  pid="$(cat "$pidfile" 2>/dev/null)" || return 1
  [ -n "$pid" ] || return 1
  kill -0 "$pid" 2>/dev/null
}

usage() {
  cat <<'EOF'
Usage:
  auto-pr-watch start <branch> [--interval SECONDS] [--base BRANCH]
  auto-pr-watch stop <branch>
  auto-pr-watch status <branch>
EOF
}

cmd_start() {
  local branch="${1:-}"
  [ -n "$branch" ] || die "start requires a branch name"
  shift || true

  local interval="$DEFAULT_INTERVAL"
  local base_override=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --interval)
        interval="${2:-}"; shift 2 ;;
      --base)
        base_override="${2:-}"; shift 2 ;;
      *)
        die "unknown argument: $1" ;;
    esac
  done

  local worktree
  worktree="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a git worktree — run 'start' from inside the worktree checked out to $branch"

  local current_branch
  current_branch="$(git -C "$worktree" branch --show-current)"
  [ "$current_branch" = "$branch" ] || die "cwd's checked-out branch ('$current_branch') does not match requested branch ('$branch') — cd into the correct worktree first"

  local sdir
  sdir="$(state_dir_for "$branch")"
  mkdir -p "$sdir"

  if is_running "$sdir/pid"; then
    die "watcher already running for $branch (pid $(cat "$sdir/pid"))"
  fi

  # Atomic lock: mkdir is an atomic operation, unlike a lockfile check+write.
  if ! mkdir "$sdir/lock" 2>/dev/null; then
    die "another start is already in progress for $branch (stale lock? remove $sdir/lock if you're sure nothing is running)"
  fi

  mkdir -p "$worktree/.auto"
  printf '%s\n' "$worktree" > "$sdir/worktree"
  printf '%s\n' "$interval" > "$sdir/interval"
  printf '%s\n' "$base_override" > "$sdir/base_override"

  # Register the repo-local scratch-state exclude, same as worktree-workflow
  # skill step 3, in case the watcher starts before research ever ran.
  local git_common_dir
  git_common_dir="$(git -C "$worktree" rev-parse --git-common-dir)"
  grep -qxF '.auto/' "$git_common_dir/info/exclude" 2>/dev/null || echo '.auto/' >> "$git_common_dir/info/exclude"

  setsid nohup "$0" _daemon "$branch" "$worktree" "$interval" "$base_override" \
    >> "$worktree/.auto/pr-watch.log" 2>&1 < /dev/null &
  local daemon_pid=$!
  disown "$daemon_pid" 2>/dev/null || true

  printf '%s\n' "$daemon_pid" > "$sdir/pid"
  rmdir "$sdir/lock"

  log "started watcher for $branch (pid $daemon_pid, interval ${interval}s, log: $worktree/.auto/pr-watch.log)"
}

cmd_stop() {
  local branch="${1:-}"
  [ -n "$branch" ] || die "stop requires a branch name"

  local sdir
  sdir="$(state_dir_for "$branch")"

  if ! is_running "$sdir/pid"; then
    log "no running watcher found for $branch"
    rm -f "$sdir/pid"
    return 0
  fi

  local pid
  pid="$(cat "$sdir/pid")"
  kill -TERM "$pid" 2>/dev/null || true

  # Give it a moment to exit cleanly, then confirm.
  local waited=0
  while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt 10 ]; do
    sleep 1
    waited=$((waited + 1))
  done

  if kill -0 "$pid" 2>/dev/null; then
    log "watcher (pid $pid) did not exit after SIGTERM, sending SIGKILL"
    kill -KILL "$pid" 2>/dev/null || true
  fi

  rm -f "$sdir/pid"
  log "stopped watcher for $branch"
}

cmd_status() {
  local branch="${1:-}"
  [ -n "$branch" ] || die "status requires a branch name"

  local sdir
  sdir="$(state_dir_for "$branch")"

  if is_running "$sdir/pid"; then
    local pid worktree
    pid="$(cat "$sdir/pid")"
    worktree="$(cat "$sdir/worktree" 2>/dev/null || echo "unknown")"
    printf 'status=running branch=%s pid=%s worktree=%s\n' "$branch" "$pid" "$worktree"
    if [ -f "$worktree/.auto/NEEDS_REBASE" ]; then
      log "NEEDS_REBASE marker present — see $worktree/.auto/NEEDS_REBASE"
    fi
    if [ -f "$worktree/.auto/pr-watch.log" ]; then
      log "last 5 log lines:"
      tail -n 5 "$worktree/.auto/pr-watch.log"
    fi
  else
    printf 'status=stopped branch=%s\n' "$branch"
  fi
}

# --- internal daemon loop, not for direct use ---
cmd_daemon() {
  local branch="$1" worktree="$2" interval="$3" base_override="$4"
  cd "$worktree" || exit 1

  log "daemon started for $branch (interval ${interval}s)"

  while true; do
    # Re-verify we're still on the branch we were started for. If a user
    # manually checked out something else in this worktree, do not touch it.
    local current_branch
    current_branch="$(git branch --show-current 2>/dev/null || true)"
    if [ "$current_branch" != "$branch" ]; then
      log "checked-out branch changed to '$current_branch' (expected '$branch') — stopping to avoid touching the wrong branch"
      break
    fi

    if ! gh pr view "$branch" --json number,state,baseRefName >/dev/null 2>&1; then
      log "no PR found for $branch (yet?) — will retry"
      sleep "$interval"
      continue
    fi

    local pr_state pr_number pr_base
    pr_state="$(gh pr view "$branch" --json state --jq '.state' 2>/dev/null)"
    pr_number="$(gh pr view "$branch" --json number --jq '.number' 2>/dev/null)"
    pr_base="${base_override:-$(gh pr view "$branch" --json baseRefName --jq '.baseRefName' 2>/dev/null)}"

    if [ "$pr_state" != "OPEN" ]; then
      log "PR #$pr_number is $pr_state — watcher exiting"
      break
    fi

    if ! git fetch origin "$pr_base" 2>>"$worktree/.auto/pr-watch.log"; then
      log "fetch of origin/$pr_base failed — will retry"
      sleep "$interval"
      continue
    fi

    local behind_count
    behind_count="$(git rev-list --count "HEAD..origin/$pr_base" 2>/dev/null || echo 0)"

    if [ "$behind_count" -eq 0 ]; then
      sleep "$interval"
      continue
    fi

    log "$branch is $behind_count commit(s) behind origin/$pr_base — attempting rebase"

    if git rebase "origin/$pr_base" >>"$worktree/.auto/pr-watch.log" 2>&1; then
      if git push --force-with-lease >>"$worktree/.auto/pr-watch.log" 2>&1; then
        log "rebased onto origin/$pr_base and pushed"
        rm -f "$worktree/.auto/NEEDS_REBASE"
      else
        log "rebase succeeded but push --force-with-lease was rejected (remote moved?) — will retry next cycle"
        # Don't force through with a bare --force. Leave the local rebase
        # in place; next cycle re-fetches and either the push succeeds or
        # we rebase again on the newer base.
      fi
    else
      git rebase --abort >>"$worktree/.auto/pr-watch.log" 2>&1 || true

      local base_sha
      base_sha="$(git rev-parse "origin/$pr_base")"
      local already_flagged=""
      if [ -f "$worktree/.auto/NEEDS_REBASE" ] && grep -qF "$base_sha" "$worktree/.auto/NEEDS_REBASE" 2>/dev/null; then
        already_flagged="yes"
      fi

      {
        printf 'auto-pr-watch: rebase onto origin/%s conflicted at %s\n' "$pr_base" "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
        printf 'base sha: %s\n' "$base_sha"
        printf 'Resolve interactively (resolve-merge-conflicts skill): git rebase origin/%s, fix conflicts, git rebase --continue, git push --force-with-lease.\n' "$pr_base"
        printf 'This marker clears automatically once the branch is no longer behind origin/%s.\n' "$pr_base"
      } > "$worktree/.auto/NEEDS_REBASE"

      log "rebase conflicted — aborted cleanly, wrote .auto/NEEDS_REBASE"

      if [ -z "$already_flagged" ]; then
        gh pr comment "$pr_number" --body "auto-agent PR watcher: automatic rebase onto \`$pr_base\` hit conflicts and was aborted (working tree left clean). This needs interactive conflict resolution — see the \`resolve-merge-conflicts\` skill. The watcher will keep retrying on its normal interval and will clear automatically once resolved and pushed." >>"$worktree/.auto/pr-watch.log" 2>&1 || log "failed to post PR comment (non-fatal)"
      else
        log "already commented for this base sha — not re-commenting"
      fi
    fi

    sleep "$interval"
  done

  local sdir
  sdir="$(state_dir_for "$branch")"
  rm -f "$sdir/pid"
  log "daemon exiting for $branch"
}

main() {
  local action="${1:-}"
  case "$action" in
    start) shift; cmd_start "$@" ;;
    stop) shift; cmd_stop "$@" ;;
    status) shift; cmd_status "$@" ;;
    _daemon) shift; cmd_daemon "$@" ;;
    -h|--help|help|"") usage ;;
    *) usage; die "unknown command: $action" ;;
  esac
}

main "$@"
