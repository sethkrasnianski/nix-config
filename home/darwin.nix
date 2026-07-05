# macOS entrypoint: standalone home-manager (flake output
# homeConfigurations.macbook), no nix-darwin — only $HOME is managed. There is
# no NixOS system layer here, so this module also stands in for
# modules/common.nix (base CLI tools, fonts, unfree allowlist).
#
# NEVER import this from a NixOS host: it sets nixpkgs.* options, which
# assert-fail under home-manager.useGlobalPkgs.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # CHANGE ME if the macOS account name differs — the single place the
  # username is defined; everything else derives from it.
  username = "seth";
in
{
  imports = [ ./default.nix ];

  home.username = username;
  home.homeDirectory = "/Users/${username}";

  # Release current at the first `home-manager switch` on the Mac. Do not
  # bump on upgrades.
  home.stateVersion = "26.05";

  # Standalone home-manager evaluates its own nixpkgs, so the predicate in
  # modules/common.nix doesn't reach here. Keep this list in sync with it.
  # NOTE: do not set nixpkgs.overlays in this file — standalone home-manager
  # already defines it (mergeOneOption, hard conflict); pass a custom
  # `pkgs = import nixpkgs { ... }` in flake.nix instead if ever needed.
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "claude-code"
      "ngrok"
    ];

  # Stand-ins for the NixOS system layer: base CLI tools from
  # modules/common.nix, plus the Doom icon font (home-manager's darwin target
  # copies fonts from home.packages into ~/Library/Fonts/HomeManager).
  home.packages = with pkgs; [
    nixfmt
    wget
    fd
    jq
    tree
    ripgrep
    nerd-fonts.symbols-only
  ];

  # Install the home-manager CLI so `rebuild` works after the first bootstrap
  # run (`nix run home-manager/master -- switch ...`, see README).
  programs.home-manager.enable = true;

  # Mirror the WSL `rebuild` alias (modules/wsl.nix). home.shellAliases lands
  # in the home-manager-managed bash/zsh rc files (home/shell.nix).
  home.shellAliases.rebuild = "home-manager switch --flake ${config.home.homeDirectory}/oss/nixos-config#macbook";
}
