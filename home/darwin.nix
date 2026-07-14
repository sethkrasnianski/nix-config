# macOS home-manager entrypoint, run as a nix-darwin module
# (darwinConfigurations.macbook, wired in hosts/macbook.nix). Only $HOME is
# managed here; the darwin system layer — base CLI tools, fonts, the unfree
# allowlist, Homebrew — lives in modules/darwin.nix.
#
# home.username / home.homeDirectory are derived from the nix-darwin user
# (useGlobalPkgs), so they are NOT set here — same as home/linux.nix. Setting
# nixpkgs.* here would assert-fail under useGlobalPkgs, which is why the unfree
# allowlist lives in modules/darwin.nix instead.
{ config, pkgs, ... }:

{
  imports = [ ./default.nix ];

  # Release current at the first `darwin-rebuild switch` on the Mac. Do not
  # bump on upgrades.
  home.stateVersion = "26.05";

  # macOS builds of apps that nixpkgs makes for darwin. firefox-bin is the
  # prebuilt Firefox (avoids a source compile on darwin); UTM is Mac-only;
  # Slack and Teams have no Linux package here (Teams was dropped from nixpkgs
  # on Linux). xcodes is the CLI that installs/switches full Xcode versions —
  # Xcode itself is not nix-installable (see README "Xcode"). vlc-bin and
  # whatsapp-for-mac are the darwin equivalents of vlc / karere in
  # home/linux.nix. Global apps live in home/default.nix.
  home.packages = with pkgs; [
    firefox-bin
    utm
    slack
    teams
    xcodes
    vlc-bin
    whatsapp-for-mac
  ];

  # Mirror the WSL `rebuild` alias (modules/wsl.nix). darwin-rebuild activates
  # the system profile, so it needs sudo. home.shellAliases lands in the
  # home-manager-managed bash/zsh rc files (home/shell.nix).
  home.shellAliases.rebuild = "sudo ${config.home.homeDirectory}/oss/nixos-config/scripts/rebuild-local.sh macbook";
}
