# Shared configuration applied to every host (WSL and non-WSL).
{
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./neovim.nix
    ./emacs.nix
    ./ssh.nix
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Tell NixOS it's ok to install these packages despite unfree license.
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "claude-code"
      "ngrok"
    ];

  # NOTE: system.stateVersion is intentionally NOT set here — it is per-host
  # (the release each machine was first installed with). See hosts/*.nix.

  # Zsh, enabled properly (completion + environment integration) rather than
  # just dropping the binary into systemPackages.
  programs.zsh.enable = true;

  # System-wide packages. (neovim comes from ./neovim.nix, emacs from ./emacs.nix)
  environment.systemPackages = with pkgs; [
    nixfmt
    wget
    git
    fd
    jq
    tree
    ripgrep
    ghostty

    # unfree
    claude-code
    ngrok
  ];
}
