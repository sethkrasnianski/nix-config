# Per-user (home-manager) configuration. Applied through the NixOS module —
# `rebuild` covers it, there is no separate home-manager switch.
{ config, pkgs, ... }:

{
  imports = [
    ./direnv.nix
    ./git.nix
    ./ssh.nix
    ./shell.nix
    ./neovim.nix
    ./emacs.nix
  ];

  # Release home-manager state was first created with. Do not bump on upgrades.
  home.stateVersion = "25.11";

  # Terminals used with this setup (Windows Terminal, Ghostty) support 24-bit
  # color but do not all advertise it. COLORTERM makes TUI apps (e.g.
  # `emacs -nw`) render truecolor instead of approximating the theme with
  # the 256-color palette.
  home.sessionVariables.COLORTERM = "truecolor";

  # User-facing apps. Base CLI tools stay in modules/common.nix.
  home.packages = with pkgs; [
    ghostty

    # unfree (allowed in modules/common.nix; useGlobalPkgs makes it apply here)
    claude-code
    ngrok
  ];

  # Doom Emacs reads its user config from ~/.config/doom; point that at the
  # real config (init.el / config.el / packages.el) tracked in this repo
  # (doom/). Claude Code's global settings are tracked here too (claude/);
  # only settings.json is linked because the rest of ~/.claude is mutable
  # state. mkOutOfStoreSymlink links to the checkout itself, so edits take
  # effect without a rebuild.
  home.file.".config/doom".source =
    config.lib.file.mkOutOfStoreSymlink "/home/nixos/personal/nixos-config/doom";
  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "/home/nixos/personal/nixos-config/claude/settings.json";
}
