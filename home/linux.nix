# NixOS entrypoint for the shared home config (home/default.nix). Wired per
# host through the home-manager NixOS module (hosts/*.nix); pkgs, username,
# and homeDirectory come from NixOS + useGlobalPkgs, so only per-machine home
# state lives here.
{ pkgs, ... }:

{
  imports = [ ./default.nix ];

  # Release home-manager state was first created with. Do not bump on upgrades.
  home.stateVersion = "25.11";

  # Linux builds of apps whose macOS equivalent differs. firefox is the free
  # source build (macOS uses the prebuilt, unfree firefox-bin); parsec-bin is
  # the Parsec client (a Homebrew cask on macOS); vlc is the full Qt build
  # (macOS uses vlc-bin); karere is the third-party GTK4 WhatsApp client (there
  # is no official Linux client — macOS uses whatsapp-for-mac); gimp is
  # Linux-only in nixpkgs (macOS gets it via the Homebrew cask in
  # modules/darwin.nix). The PhotoGIMP overlay (home/photogimp.nix) seeds
  # GIMP's config dir on both platforms. Global apps live in home/default.nix.
  home.packages = with pkgs; [
    firefox
    parsec-bin
    vlc
    karere
    gimp
  ];
}
