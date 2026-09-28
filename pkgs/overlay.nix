# Packages not in nixpkgs, added to every host via modules/common.nix
# (NixOS) and modules/darwin.nix (macOS). Imported by both rather than
# duplicated, same rule as everything else in this repo.
final: prev: {
  prime-agent = final.callPackage ./prime-agent { };

  # claude-code 2.1.280 added Claude Opus 5.5 (`claude-opus-5-5`); our nixpkgs pin
  # still carries 2.1.276, so the model is not offered. The derivation takes its
  # version and download checksums from one overridable `manifest` argument, and
  # the package.nix at our pin is identical to nixos-unstable's — so swapping just
  # the manifest is equivalent to taking the newer package, without fetching a
  # second nixpkgs tree. Values copied verbatim from upstream's published
  # https://downloads.claude.ai/claude-code-releases/2.1.283/manifest.zst.json.
  # Drop this override once a routine `nix flake update` reaches claude-code 2.1.283.
  claude-code = prev.claude-code.override {
    manifest = {
      version = "2.1.283";
      platforms = {
        # keys are "${hostPlatform.node.platform}-${hostPlatform.node.arch}"
        linux-x64 = {
          binary = "claude.zst";
          checksum = "94345861e88be3d67a8393494f98f5b1c67604c14ccd4ef3c7a51e3643fa25eb";
        };
        linux-arm64 = {
          binary = "claude.zst";
          checksum = "7ff80952f5cf74fa593432ec19fc7bef1b4461b365092fe2b6c6060d4fbad1ec";
        };
        darwin-arm64 = {
          binary = "claude.zst";
          checksum = "485d6883c023368800626e0d1f2e4382c3e1bdc760fae12cb2f6e3054f218eec";
        };
      };
    };
  };

  # Keep the OpenCode packaging fix from nixpkgs PR #564101 (Bun's regression
  # in code splitting broke prompts), while advancing to upstream 1.18.33 ahead
  # of our nixpkgs pin. The node_modules output hash is for this release's lockfile.
  opencode =
    let
      fixedNixpkgs = import (builtins.fetchTree {
        type = "github";
        owner = "NixOS";
        repo = "nixpkgs";
        rev = "d4448fee6bab71511ac36747a98a2aad35544852";
      }) { inherit (prev) system; };
      version = "1.18.33";
      src = final.fetchFromGitHub {
        owner = "anomalyco";
        repo = "opencode";
        tag = "v${version}";
        hash = "sha256-x1ZG4/zsL1/EfpelNByRMi5mSHumXfmoq/LPQ3+jhrc=";
      };
    in
    fixedNixpkgs.opencode.overrideAttrs (old: {
      inherit version src;
      passthru = old.passthru // {
        node_modules = old.passthru.node_modules.overrideAttrs (_: {
          inherit version src;
          outputHash = "sha256-3QJzASZSJfWqbFpbxzIQ/ZRRaFX8KAF4Jd2BI6v9e+s=";
        });
      };
    });
}
