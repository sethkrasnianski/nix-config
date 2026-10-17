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
  # nixpkgs-unstable f20cd90 packages this release with the same manifest.
  # https://downloads.claude.ai/claude-code-releases/2.1.300/manifest.zst.json.
  # Drop this override once a routine `nix flake update` reaches claude-code 2.1.300.
  claude-code = prev.claude-code.override {
    manifest = {
      version = "2.1.300";
      platforms = {
        # keys are "${hostPlatform.node.platform}-${hostPlatform.node.arch}"
        linux-x64 = {
          binary = "claude.zst";
          checksum = "ca1608ae4e85017c5408c85a3778410add7dd796324acfd0eef3ad707268d5d6";
        };
        linux-arm64 = {
          binary = "claude.zst";
          checksum = "1f87b1a7838056aaf69c2b819c0b6b118ac713e0e2ba6c0a768aa531c7c5e8d0";
        };
        darwin-arm64 = {
          binary = "claude.zst";
          checksum = "5f19cc8fef7b1387f4b71691213b5aadc62d9157a78014287f3002ce8642cc23";
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

  # Use the Codex 0.162.1 package from the nixpkgs-unstable registry channel.
  # Its pinned package set keeps the daemon, voice, and V8 runtimes compatible.
  codex =
    let
      codexPkgs =
        import
          (builtins.fetchTarball {
            url = "https://releases.nixos.org/nixpkgs/nixpkgs-26.11pre1093421.f20cd90e28fe/nixexprs.tar.zst";
            sha256 = "sha256-MTJCMrhDFb+GRbLxBPTp8kB4dDlO+egmQ5qsJgYuaWw=";
          })
          {
            inherit (prev.stdenv.hostPlatform) system;
          };
    in
    codexPkgs.codex;

  # Use nixpkgs-unstable f20cd90's release and hashes ahead of our system pin.
  # Keep the Bun packaging fix and match node_modules to this release's lockfile.
  opencode =
    let
      version = "1.19.0";
      src = final.fetchFromGitHub {
        owner = "anomalyco";
        repo = "opencode";
        tag = "v${version}";
        hash = "sha256-XL76Qpm4GEFEn7Pt7g84sx+djEKnlpTTZXRgXJF3NRs=";
      };
    in
    prev.opencode.overrideAttrs (old: {
      inherit version src;
      passthru = old.passthru // {
        node_modules = old.passthru.node_modules.overrideAttrs (_: {
          inherit version src;
          outputHash = "sha256-RLHrfyBM6fMglKyEkdkW+Mmfzzr6q/U7R38goaQcIhA=";
        });
      };
    });
}
