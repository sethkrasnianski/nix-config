# NixOS entrypoint for the shared home config (home/default.nix). Wired per
# host through the home-manager NixOS module (hosts/*.nix); pkgs, username,
# and homeDirectory come from NixOS + useGlobalPkgs, so only per-machine home
# state lives here.
{ ... }:

{
  imports = [ ./default.nix ];

  # Release home-manager state was first created with. Do not bump on upgrades.
  home.stateVersion = "25.11";
}
