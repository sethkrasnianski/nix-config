# WSL host. The nixos-wsl module is supplied by flake.nix.
{ ... }:

{
  imports = [
    ../modules/common.nix
    ../modules/desktop.nix
    ../modules/wsl.nix
  ];

  networking.hostName = "nixos";

  # Doom Emacs reads its user config from ~/.config/doom; point that at the
  # real config (init.el / config.el / packages.el) tracked in this repo
  # (doom/). Host-specific because this checkout only exists on this machine.
  systemd.tmpfiles.rules = [
    "L+ /home/nixos/.config/doom - - - - /home/nixos/personal/nixos-config/doom"
  ];

  # Release this machine was first installed with. Do not bump on upgrades.
  system.stateVersion = "25.11";
}
