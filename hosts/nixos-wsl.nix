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
  # (doom/). Claude Code's global settings are tracked here too (claude/);
  # only settings.json is linked because the rest of ~/.claude is mutable
  # state. Host-specific because this checkout only exists on this machine.
  systemd.tmpfiles.rules = [
    "L+ /home/nixos/.config/doom - - - - /home/nixos/personal/nixos-config/doom"
    "L+ /home/nixos/.claude/settings.json - - - - /home/nixos/personal/nixos-config/claude/settings.json"
  ];

  # Release this machine was first installed with. Do not bump on upgrades.
  system.stateVersion = "25.11";
}
