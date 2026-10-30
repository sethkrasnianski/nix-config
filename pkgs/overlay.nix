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
  # https://downloads.claude.ai/claude-code-releases/2.1.312/manifest.zst.json.
  # Drop this override once a routine `nix flake update` reaches claude-code 2.1.312.
  claude-code = prev.claude-code.override {
    manifest = {
      version = "2.1.312";
      platforms = {
        # keys are "${hostPlatform.node.platform}-${hostPlatform.node.arch}"
        linux-x64 = {
          binary = "claude.zst";
          checksum = "6fb9e329947c003740be888f98db1aecaa238d6c7d9ceef8581eb71d5a59480b";
        };
        linux-arm64 = {
          binary = "claude.zst";
          checksum = "863ee1d2a91a39ee22fa13322582e4c3fb45bfb4739b22ec7e396dde694d8581";
        };
        darwin-arm64 = {
          binary = "claude.zst";
          checksum = "7d759495d011057b6e8b8ee911c5be3cd36e9491c71a4ab194a425cdb1418073";
        };
      };
    };
  };

  # Keep Linux's source build and update the wrapper and security metadata together.
  # The source checksum comes from Mozilla's release SHA512SUMS.
  firefox-unwrapped = prev.firefox-unwrapped.overrideAttrs (
    finalAttrs: old: {
      version = "157.0.1";
      src = final.fetchurl {
        url = "mirror://mozilla/firefox/releases/${finalAttrs.version}/source/firefox-${finalAttrs.version}.source.tar.xz";
        sha512 = "c019202b2f87d25b3605bbf7266f3bb4d59745e48536f297d3f00cc3524a1cd2eba416a5a3cd0ecee6b0762d0f35bf3c5fcce286ebc7bc741263bebd0f102858";
      };
      passthru = old.passthru // {
        inherit (finalAttrs) version;
      };
      meta = old.meta // {
        changelog = "https://www.firefox.com/en-US/firefox/${finalAttrs.version}/releasenotes/";
        identifiers = old.meta.identifiers // {
          cpeParts = old.meta.identifiers.cpeParts // {
            inherit (finalAttrs) version;
          };
          purlParts = old.meta.identifiers.purlParts // {
            spec = "firefox@${finalAttrs.version}";
          };
        };
      };
    }
  );

  # Read the pinned Mozilla checksums to preserve every platform and locale choice.
  # The inherited macOS package keeps the unwrapped, signed application bundle.
  firefox-bin-unwrapped = prev.firefox-bin-unwrapped.override {
    generated =
      let
        version = "157.0.1";
        baseUrl = "https://archive.mozilla.org/pub/firefox/releases/${version}";
        checksums = builtins.readFile (
          builtins.fetchurl {
            url = "${baseUrl}/SHA256SUMS";
            sha256 = "16e808f33acfacfe6922ac182f1086faeb143970d61e2a11e55c422b8b33b316";
          }
        );
        matches = builtins.filter (match: match != null) (
          map (builtins.match "([0-9a-f]{64})  ((linux-[^/]+|mac)/([^/]+)/(firefox-.+[.]tar[.]xz|Firefox .+[.]dmg))") (
            final.lib.splitString "\n" checksums
          )
        );
      in
      {
        inherit version;
        sources = map (match: {
          url = "${baseUrl}/${builtins.elemAt match 1}";
          sha256 = builtins.elemAt match 0;
          arch = builtins.elemAt match 2;
          locale = builtins.elemAt match 3;
        }) matches;
      };
  };

  # Use the Codex 0.165.0 package from the nixpkgs-unstable registry channel.
  # Its pinned package set keeps the daemon, voice, and V8 runtimes compatible.
  codex =
    let
      codexPkgs =
        import
          (builtins.fetchTarball {
            url = "https://releases.nixos.org/nixpkgs/nixpkgs-26.11pre1104102.e62746b0b472/nixexprs.tar.zst";
            sha256 = "sha256-GYpArmwi/iMuX2ov31oCBhAXRMJdNX9kOl2LZHCuR6M=";
          })
          {
            inherit (prev.stdenv.hostPlatform) system;
          };
    in
    codexPkgs.codex;
}
