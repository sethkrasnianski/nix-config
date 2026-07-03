# WSL host. The nixos-wsl module is supplied by flake.nix.
{ ... }:

{
  imports = [
    ../modules/common.nix
    ../modules/desktop.nix
    ../modules/wsl.nix
  ];

  networking.hostName = "nixos";

  # Release this machine was first installed with. Do not bump on upgrades.
  system.stateVersion = "25.11";
}
