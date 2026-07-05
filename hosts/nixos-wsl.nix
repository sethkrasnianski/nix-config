# WSL host. The nixos-wsl module is supplied by flake.nix.
{ ... }:

{
  imports = [
    ../modules/common.nix
    ../modules/desktop.nix
    ../modules/wsl.nix
  ];

  networking.hostName = "nixos";

  # Per-user config (dotfiles, user packages, shells) — see home/ at the repo
  # root. Wired per-host because the username is host-specific (here it's the
  # WSL default user from modules/wsl.nix). linux.nix is the NixOS entrypoint;
  # it carries the per-machine home.stateVersion.
  home-manager.users.nixos = import ../home/linux.nix;

  # Release this machine was first installed with. Do not bump on upgrades.
  system.stateVersion = "25.11";
}
