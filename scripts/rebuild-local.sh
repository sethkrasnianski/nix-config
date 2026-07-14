#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
target=${1:?usage: rebuild-local.sh nixos|nixos-headless|nixos-default|macbook}

case "$target" in
  nixos|nixos-headless|nixos-default) command=nixos-rebuild ;;
  macbook) command=darwin-rebuild ;;
  *) printf 'unknown target: %s\n' "$target" >&2; exit 2 ;;
esac

set -- "$command" switch --flake "$repo#$target"
if [ -d "$repo/.local/config" ]; then
  set -- "$@" --override-input local-config "path:$repo/.local/config"
fi
exec "$@"
