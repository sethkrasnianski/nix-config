# Non-WSL host template. Contains no WSL code, so it builds on real hardware.
{ ... }:

{
  imports = [
    ../modules/common.nix
    ../modules/desktop.nix
    ./nixos-default-hardware.nix
  ];

  networking.hostName = "nixos-default";

  # A non-WSL machine needs a bootloader. Adjust for your hardware
  # (this assumes UEFI + systemd-boot).
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # CHANGE ME at first install: set to the NixOS release current at that time
  # (this placeholder assumes a 25.11-era install). Do not bump on upgrades.
  system.stateVersion = "25.11";
}
