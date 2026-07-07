# NixOS entrypoint for the shared home config (home/default.nix). Wired per
# host through the home-manager NixOS module (hosts/*.nix); pkgs, username,
# and homeDirectory come from NixOS + useGlobalPkgs, so only per-machine home
# state lives here.
{ pkgs, ... }:

{
  imports = [ ./default.nix ];

  # Release home-manager state was first created with. Do not bump on upgrades.
  home.stateVersion = "25.11";

  # Linux builds of apps whose macOS equivalent differs. parsec-bin is the
  # Parsec client (a Homebrew cask on macOS); vlc is the full Qt build (macOS
  # uses vlc-bin); karere is the third-party GTK4 WhatsApp client (there is no
  # official Linux client — macOS uses whatsapp-for-mac). Global apps live in
  # home/default.nix.
  home.packages = with pkgs; [
    parsec-bin
    vlc
    karere
  ];
}
