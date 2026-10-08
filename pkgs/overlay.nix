# Packages not in nixpkgs, added to every host via modules/common.nix
# (NixOS) and modules/darwin.nix (macOS). Imported by both rather than
# duplicated, same rule as everything else in this repo.
final: prev: {
  prime-agent = final.callPackage ./prime-agent { };
  synergy3 = final.callPackage ./synergy3 { };

  # Our nixpkgs pin lags Claude Code releases. Its derivation takes its version
  # and platform checksums from one overridable `manifest` argument, so swapping
  # just the manifest is equivalent to taking the newer package without fetching
  # another nixpkgs tree. Values are from Anthropic's compressed release manifest
  # (the plain manifest has different checksums):
  # https://downloads.claude.ai/claude-code-releases/2.1.284/manifest.zst.json.
  # Drop this override once a routine `nix flake update` reaches claude-code 2.1.284.
  claude-code = prev.claude-code.override {
    manifest = {
      version = "2.1.284";
      platforms = {
        # keys are "${hostPlatform.node.platform}-${hostPlatform.node.arch}"
        linux-x64 = {
          binary = "claude.zst";
          checksum = "5021d631dacbd516603a779b3cf2463085470417a838b6a0835f77fa44d23f0a";
        };
        linux-arm64 = {
          binary = "claude.zst";
          checksum = "6e31b86de3952594441b4ef91c1f5079c1385b0169a9df351dd2762bb2336d23";
        };
        darwin-arm64 = {
          binary = "claude.zst";
          checksum = "ed26ee9ccbf05b2dfa3c8abf52348b78b00274304824ad1eeaf9d88366fa70ae";
        };
      };
    };
  };

  # Use the release ahead of our nixpkgs pin, which includes the Bun packaging fix.
  # The node_modules output hash must match this release's lockfile.
  opencode =
    let
      version = "1.18.35";
      src = final.fetchFromGitHub {
        owner = "anomalyco";
        repo = "opencode";
        tag = "v${version}";
        hash = "sha256-NM5AbX99hDW+oIojiHSRA+QDz27d8L/v42bwZY+6Imk=";
      };
    in
    prev.opencode.overrideAttrs (old: {
      inherit version src;
      passthru = old.passthru // {
        node_modules = old.passthru.node_modules.overrideAttrs (_: {
          inherit version src;
          outputHash = "sha256-cQLuGI8MBh9l8GisM2k5WXBcZrsdgrNsXUOsYzZVwYY=";
        });
      };
    });
}
