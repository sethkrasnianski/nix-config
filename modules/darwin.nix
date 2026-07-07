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

  # Unfree allowlist for the Mac. home-manager.useGlobalPkgs (hosts/macbook.nix)
  # makes this cover home.packages too. KEEP IN SYNC with the copy in
  # modules/common.nix — the NixOS hosts maintain their own list, and the two
  # drift silently otherwise.
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "claude-code"
      "ngrok"
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
    wget
    fd
    jq
    tree
    ripgrep
  ];

  # Declarative Homebrew for the macOS GUI apps nixpkgs can't build on darwin
  # (Parsec, Steam, Mullvad — see homebrew.casks below). nix-homebrew manages
  # the Homebrew installation itself; the owning `user` is set in
  # hosts/macbook.nix. The homebrew module declares the casks and reconciles
  # them on `darwin-rebuild switch` — cleanup = "uninstall" removes any cask no
  # longer listed here, making this file the source of truth.
  nix-homebrew.enable = true;
  homebrew = {
    enable = true;
    casks = [ ];
    onActivation = {
      cleanup = "uninstall";
      autoUpdate = false;
    };
  };
}
