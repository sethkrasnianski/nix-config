# Shared nix-darwin system config for the Mac (darwinConfigurations.macbook).
# This is the darwin counterpart to modules/common.nix, which is NixOS-only and
# must NOT be imported here. Per-machine facts (username, hostPlatform,
# stateVersion) live in hosts/macbook.nix.
{
  lib,
  pkgs,
  ...
}:

{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Packages not in nixpkgs (Prime Agent and Synergy 3) — shared with
  # modules/common.nix via the same file, never duplicated.
  nixpkgs.overlays = [ (import ../pkgs/overlay.nix) ];

  # Unfree allowlist for the Mac. home-manager.useGlobalPkgs (hosts/macbook.nix)
  # makes this cover home.packages too. KEEP IN SYNC with the copy in
  # modules/common.nix — the NixOS hosts maintain their own list, and the two
  # drift silently otherwise. synergy3 is the pinned Apple Silicon DMG package,
  # installed by modules/synergy3-darwin.nix.
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "claude-code"
      "ngrok"
      "obsidian"
      "spotify"
      "synergy3"
    ];

  # Icon font used by Doom Emacs' UI (modeline, treemacs, dashboard). nix-darwin
  # installs fonts into /Library/Fonts via fonts.packages.
  fonts.packages = [ pkgs.nerd-fonts.symbols-only ];

  # Register zsh's completion/environment plumbing (matches modules/common.nix).
  # Apple's /bin/zsh stays the login shell and sources the home-manager rc files.
  programs.zsh.enable = true;

  # Base CLI tools kept system-wide — the darwin stand-in for the tools
  # modules/common.nix installs on NixOS. User-facing apps live in home/.
  environment.systemPackages = with pkgs; [
    nixfmt
    awscli2
    teleport
    gws
    wget
    fd
    jq
    tree
    ripgrep
  ];

  # Declarative Homebrew for the macOS GUI apps nixpkgs can't build on darwin
  # (ChatGPT, Parsec, Mullvad — see homebrew.casks below). nix-homebrew
  # manages the Homebrew installation itself; the owning `user` is set in
  # hosts/macbook.nix. The homebrew module declares the casks and reconciles
  # them on `darwin-rebuild switch` — cleanup = "uninstall" removes any cask no
  # longer listed here, making this file the source of truth. Contexts add
  # their own casks to this list; the base installs no Claude Desktop.
  # Auto-install the Xcode Command Line Tools (git, clang, make, headers) on
  # the first activation if they're absent, so the Mac is self-contained — no
  # separate manual step in the bootstrap docs. `xcode-select --install`
  # triggers Apple's GUI installer and returns immediately (it does not block
  # the rebuild); confirm the prompt once and the download proceeds in the
  # background. Most nix-driven work uses nix's own toolchain; this is a
  # convenience for tools that reach for the system SDK. Full Xcode is separate
  # (see README "Xcode"). Guarded so it's a no-op once the tools are present.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    if ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
      echo "Xcode Command Line Tools not found — launching Apple's installer..."
      /usr/bin/xcode-select --install || true
    fi
  '';

  # Opt out of Homebrew analytics for all shells.
  environment.variables.HOMEBREW_NO_ANALYTICS = "1";

  nix-homebrew.enable = true;
  homebrew = {
    enable = true;
    # The GUI apps nixpkgs can't build on darwin. Nix manages their Linux
    # counterparts: parsec-bin (home/linux.nix) and services.mullvad-vpn
    # (modules/common.nix). Steam and GIMP are not in the base on macOS. A
    # context adds those casks, and sets programs.photogimp.enable
    # (home/photogimp.nix) to seed GIMP's config.
    casks = [
      "chatgpt"
      "parsec"
      "mullvad-vpn"
    ];
    onActivation = {
      cleanup = "uninstall";
      autoUpdate = false;
    };
  };
}
