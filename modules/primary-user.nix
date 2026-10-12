# Declares `local.primaryUser`, the macOS account that owns the home-manager,
# Homebrew, and Dock config in hosts/macbook.nix. Defaults to the author's
# account; a Mac with a different account name sets
# `local.primaryUser = "<name>";` in ~/.config/nix/local.nix (copied into the
# flake as the `local-config` input by scripts/rebuild-local.sh).
{ lib, ... }:

{
  options.local.primaryUser = lib.mkOption {
    type = lib.types.str;
    default = "sethkrasnianski";
    description = "macOS account name used for the user's home directory and per-user config.";
  };
}
