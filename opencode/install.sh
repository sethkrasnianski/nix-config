#!/usr/bin/env bash
#
# install.sh — install auto-agent into OpenCode's global config so it's
# available in every repo, from any starting directory.
#
# Installs at the per-item level (each agent .md, each skill directory,
# each command .md) rather than symlinking whole parent directories, so
# any other custom agents/commands/skills you already have globally are
# left untouched. Also installs the PR-watch daemon onto PATH.
#
# Safe to re-run (idempotent): existing correct symlinks are left alone.
# Never silently overwrites a real (non-symlink) file — those are backed
# up with a timestamped suffix first.
#
# Usage:
#   ./install.sh                 install everything
#   ./install.sh --uninstall     remove only the symlinks this script created
#   ./install.sh --dry-run       show what would happen, change nothing

set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
BIN_DIR="$HOME/.local/bin"

DRY_RUN=""
UNINSTALL=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN="1" ;;
    --uninstall) UNINSTALL="1" ;;
    -h|--help)
      cat <<'EOF'
Usage:
  ./install.sh                 install everything
  ./install.sh --uninstall     remove only the symlinks this script created
  ./install.sh --dry-run       show what would happen, change nothing
EOF
      exit 0
      ;;
    *)
      echo "unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

INSTALLED=0
SKIPPED=0
BACKED_UP=0

note() { printf '%s\n' "$*"; }

# link_item TARGET_PATH SOURCE_PATH
# Creates (or reports it would create) a symlink at TARGET_PATH pointing to
# SOURCE_PATH. Handles four cases: missing target (create), correct existing
# symlink (no-op), wrong/foreign symlink or real file/dir (back up, then
# create).
link_item() {
  local target="$1" source="$2"

  if [ -L "$target" ]; then
    local current
    current="$(readlink "$target")"
    if [ "$current" = "$source" ]; then
      SKIPPED=$((SKIPPED + 1))
      return 0
    fi
    note "  existing symlink points elsewhere ($current) — will relink"
    if [ -z "$DRY_RUN" ]; then
      rm "$target"
    fi
  elif [ -e "$target" ]; then
    local backup
    backup="${target}.pre-auto-agent.$(date +%Y%m%d%H%M%S)"
    note "  backing up existing $(basename "$target") -> $(basename "$backup")"
    BACKED_UP=$((BACKED_UP + 1))
    if [ -z "$DRY_RUN" ]; then
      mv "$target" "$backup"
    fi
  fi

  note "  linking $(basename "$target")"
  INSTALLED=$((INSTALLED + 1))
  if [ -z "$DRY_RUN" ]; then
    ln -s "$source" "$target"
  fi
}

# unlink_item TARGET_PATH SOURCE_PATH
# Removes TARGET_PATH only if it's a symlink pointing at SOURCE_PATH — never
# touches a real file/dir or a symlink pointing somewhere else (that's
# either user content or a backup we should leave alone).
unlink_item() {
  local target="$1" source="$2"

  if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
    note "  removing $(basename "$target")"
    if [ -z "$DRY_RUN" ]; then
      rm "$target"
    fi
    INSTALLED=$((INSTALLED + 1))
  fi
}

do_uninstall() {
  note "Uninstalling auto-agent from $CONFIG_DIR ..."

  note "Agents:"
  for src in "$REPO_ROOT"/agents/*.md; do
    [ -e "$src" ] || continue
    unlink_item "$CONFIG_DIR/agents/$(basename "$src")" "$src"
  done

  note "Commands:"
  for src in "$REPO_ROOT"/commands/*.md; do
    [ -e "$src" ] || continue
    unlink_item "$CONFIG_DIR/commands/$(basename "$src")" "$src"
  done

  note "Skills:"
  for src in "$REPO_ROOT"/skills/*/; do
    [ -e "$src" ] || continue
    src="${src%/}"
    unlink_item "$CONFIG_DIR/skills/$(basename "$src")" "$src"
  done

  note "Plugins:"
  for src in "$REPO_ROOT"/plugins/*.js; do
    [ -e "$src" ] || continue
    unlink_item "$CONFIG_DIR/plugins/$(basename "$src")" "$src"
  done

  note "PR watch script:"
  unlink_item "$BIN_DIR/auto-pr-watch" "$REPO_ROOT/scripts/pr-watch.sh"

  note "History finalizer:"
  unlink_item "$BIN_DIR/auto-history-finalize" "$REPO_ROOT/scripts/history-finalize.sh"

  note ""
  note "Removed $INSTALLED item(s). Backups (if any were made on install) were left in place — remove *.pre-auto-agent.* files manually once you've confirmed you don't need them."
}

do_install() {
  note "Installing auto-agent from $REPO_ROOT into $CONFIG_DIR ..."
  [ -n "$DRY_RUN" ] && note "(dry run — no changes will be made)"
  note ""

  if [ -z "$DRY_RUN" ]; then
    mkdir -p "$CONFIG_DIR/agents" "$CONFIG_DIR/commands" "$CONFIG_DIR/skills" "$CONFIG_DIR/plugins" "$BIN_DIR"
  fi

  note "Agents:"
  for src in "$REPO_ROOT"/agents/*.md; do
    [ -e "$src" ] || continue
    link_item "$CONFIG_DIR/agents/$(basename "$src")" "$src"
  done

  note "Commands:"
  for src in "$REPO_ROOT"/commands/*.md; do
    [ -e "$src" ] || continue
    link_item "$CONFIG_DIR/commands/$(basename "$src")" "$src"
  done

  note "Skills:"
  for src in "$REPO_ROOT"/skills/*/; do
    [ -e "$src" ] || continue
    src="${src%/}" # strip trailing slash from the glob match
    link_item "$CONFIG_DIR/skills/$(basename "$src")" "$src"
  done

  note "Plugins:"
  for src in "$REPO_ROOT"/plugins/*.js; do
    [ -e "$src" ] || continue
    link_item "$CONFIG_DIR/plugins/$(basename "$src")" "$src"
  done

  note "PR watch script:"
  if [ -z "$DRY_RUN" ]; then
    chmod +x "$REPO_ROOT/scripts/pr-watch.sh" "$REPO_ROOT/scripts/history-finalize.sh"
  fi
  link_item "$BIN_DIR/auto-pr-watch" "$REPO_ROOT/scripts/pr-watch.sh"

  note "History finalizer:"
  link_item "$BIN_DIR/auto-history-finalize" "$REPO_ROOT/scripts/history-finalize.sh"

  note ""
  note "Done: $INSTALLED linked/updated, $SKIPPED already up to date, $BACKED_UP backed up."

  case ":$PATH:" in
    *":$BIN_DIR:"*) : ;;
    *) note "" ; note "Note: $BIN_DIR is not on your PATH — add it so 'auto-pr-watch' is directly runnable, e.g.:" ; note "  export PATH=\"$BIN_DIR:\$PATH\"" ;;
  esac

  note ""
  note "auto-agent is now available globally. In any repo, run: opencode, then /auto <goal>"
  note "For per-project overrides, run /auto-init inside that repo's OpenCode session."
}

if [ -n "$UNINSTALL" ]; then
  do_uninstall
else
  do_install
fi
