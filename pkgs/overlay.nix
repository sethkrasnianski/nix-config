# Packages not in nixpkgs, added to every host via modules/common.nix
# (NixOS) and modules/darwin.nix (macOS). Imported by both rather than
# duplicated, same rule as everything else in this repo.
final: prev: {
  prime-agent = final.callPackage ./prime-agent { };

  # opencode 1.18.30 as built on our pinned nixpkgs crashes every prompt with
  # "Unexpected server error" (TypeError in SystemPrompt.environment) —
  # Bun 1.4.2 code-splitting regression, https://github.com/NixOS/nixpkgs/issues/563241.
  # Fixed in nixpkgs by https://github.com/NixOS/nixpkgs/pull/564101, merged
  # 2026-09-18, but not yet in the nixos-unstable channel we track. Pull just
  # this one package from the fix commit until our nixpkgs pin catches up
  # (binary-cache hit, no local rebuild). Drop this override once a routine
  # `nix flake update` advances past that commit.
  opencode =
    (import
      (builtins.fetchTree {
        type = "github";
        owner = "NixOS";
        repo = "nixpkgs";
        rev = "d4448fee6bab71511ac36747a98a2aad35544852";
      })
      { inherit (prev) system; }
    ).opencode;
}
