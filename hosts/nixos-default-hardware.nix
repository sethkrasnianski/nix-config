# PLACEHOLDER hardware description for the non-WSL host.
#
# On the real machine, run:  sudo nixos-generate-config
# and replace this file's contents with the generated
# /etc/nixos/hardware-configuration.nix.
#
# The stub below only exists so `nixosConfigurations.nixos-default` evaluates. It is
# NOT bootable as-is.
{ lib, ... }:

{
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
