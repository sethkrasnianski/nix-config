#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
target=${1:?usage: rebuild-local.sh nixos|nixos-headless|nixos-default|macbook}
# Canonicalize to the physical path: Nix's path: fetcher refuses input paths
# whose ancestors are symlinks (macOS /tmp and $TMPDIR go through /var ->
# private/var). A no-op where TMPDIR has no symlinked components (Linux).
local_input_dir=$(mktemp -d "${TMPDIR:-/tmp}/nixos-config-local.XXXXXX")
local_input_dir=$(cd "$local_input_dir" && pwd -P)
trap 'rm -rf "$local_input_dir"' EXIT

case "$target" in
  nixos|nixos-headless|nixos-default)
    command=nixos-rebuild
    flake="$repo#$target"
    ;;
  # darwin-rebuild runs as root, which cannot open this user's Git checkout.
  macbook)
    command=darwin-rebuild
    flake="path:$repo#$target"
    ;;
  *) printf 'unknown target: %s\n' "$target" >&2; exit 2 ;;
esac

if [ -f "$HOME/.config/nix/local.nix" ]; then
  cp "$HOME/.config/nix/local.nix" "$local_input_dir/default.nix"
  override_input="path:$local_input_dir"
else
  override_input=""
fi

if [ -n "$override_input" ]; then
  sudo "$command" switch --flake "$flake" --override-input local-config "$override_input"
  exit $?
fi
sudo "$command" switch --flake "$flake"
