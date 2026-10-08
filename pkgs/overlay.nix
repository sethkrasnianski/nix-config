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

  # Keep the nixpkgs sandbox wrapper, daemon patch, completions, and code-mode host.
  # This release still uses V8 150.4.0 from the pinned package.
  codex = prev.codex.overrideAttrs (
    finalAttrs: _: {
      version = "0.161.0";
      src = final.fetchFromGitHub {
        owner = "openai";
        repo = "codex";
        tag = "rust-v${finalAttrs.version}";
        hash = "sha256-a6cNz/rKb2L4pFOTBSutNbR7aNyzTI3wF0X7gwidj6g=";
      };
      cargoHash = "sha256-y9TVxrqMQvPUbIhTkfrSCnH/NMp/Liz3rpwSK4AjoMA=";
      cargoDeps = final.rustPlatform.fetchCargoVendor {
        inherit (finalAttrs)
          pname
          version
          src
          sourceRoot
          ;
        hash = finalAttrs.cargoHash;
      };
    }
  );

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
