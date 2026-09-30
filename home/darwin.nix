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

  # macOS builds of apps that nixpkgs makes for darwin. firefox-bin-unwrapped is
  # the prebuilt Firefox (avoids a source compile on darwin). It is the
  # unwrapped build on purpose: the firefox-bin wrapper's CFBundleExecutable is
  # a bash script that execs the binary in a different store bundle, so the
  # open-URL Apple Events LaunchServices sends never reach the process and every
  # link opens a blank window. UTM is Mac-only;
  # Slack has no Linux package here. xcodes is the CLI that installs/switches
  # full Xcode versions — Xcode itself is not nix-installable (see README
  # "Xcode"). vlc-bin and whatsapp-for-mac are the darwin equivalents of vlc /
  # karere in home/linux.nix. Global apps live in home/default.nix.
  home.packages = with pkgs; [
    firefox-bin-unwrapped
    utm
    slack
    xcodes
    vlc-bin
    whatsapp-for-mac
    # Container runtime for macOS: colima runs the Linux VM (start it with
    # `colima start`; not autostarted), docker is the CLI that talks to it.
    # Needed by the sonarqube MCP server and the Makefile image builds in
    # morpheos-nucleus. The buildx/compose plugins are linked below.
    colima
    docker
  ];

  # The docker CLI discovers plugins in ~/.docker/cli-plugins. Link them there
  # rather than editing ~/.docker/config.json, which colima rewrites to add its
  # docker context.
  home.file.".docker/cli-plugins/docker-buildx".source = "${pkgs.docker-buildx}/bin/docker-buildx";
  home.file.".docker/cli-plugins/docker-compose".source = "${pkgs.docker-compose}/bin/docker-compose";

  # Mirror the WSL `rebuild` alias (modules/wsl.nix). The helper invokes sudo
  # after reading the user's local.nix, so $HOME resolves correctly. home.shellAliases lands in the
  # home-manager-managed bash/zsh rc files (home/shell.nix).
  home.shellAliases.rebuild = "${config.home.homeDirectory}/oss/nixos-config/scripts/rebuild-local.sh macbook";
}
