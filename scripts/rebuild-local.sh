#!/bin/sh
set -eu

repo=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
target=${1:?usage: rebuild-local.sh nixos|nixos-headless|nixos-default|macbook}
shift

# Bootstrap works before the packaged config command is installed. A normal
# invocation uses the installed Python, supplied by home/config.nix.
if command -v python3 >/dev/null 2>&1; then
  exec python3 "$repo/scripts/config.py" --repo "$repo" rebuild --target "$target" "$@"
fi
case "$target" in
  macbook) python="$repo#darwinConfigurations.macbook.pkgs.python3" ;;
  *) python="$repo#nixosConfigurations.nixos.pkgs.python3" ;;
esac
exec nix shell "$python" -c \
  python3 "$repo/scripts/config.py" --repo "$repo" rebuild --target "$target" "$@"
