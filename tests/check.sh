#!/usr/bin/env bash
# Linux CI entry point: test real context composition, then evaluate every host.
set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
if [[ "$PWD" != "$repo" ]]; then
  printf 'Run this check from %s\n' "$repo" >&2
  exit 1
fi

NIX_CONFIG_INTEGRATION=1 nix shell \
  .#nixosConfigurations.nixos.pkgs.python3 \
  .#nixosConfigurations.nixos.pkgs.direnv \
  -c python3 -B -m unittest discover -s tests -p '*_test.py' -v
nix eval --impure --json --file tests/contexts-eval.nix
for target in nixos nixos-headless nixos-default; do
  printf '\nEvaluating %s\n' "$target"
  nix eval ".#nixosConfigurations.$target.config.system.build.toplevel.drvPath" --raw
done
printf '\nEvaluating macbook\n'
nix eval .#darwinConfigurations.macbook.system.drvPath --raw
printf '\n'
