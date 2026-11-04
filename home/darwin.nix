# macOS home-manager entrypoint, run as a nix-darwin module
# (darwinConfigurations.macbook, wired in hosts/macbook.nix). Only $HOME is
# managed here; the darwin system layer — base CLI tools, fonts, the unfree
# allowlist, Homebrew — lives in modules/darwin.nix.
#
# home.username / home.homeDirectory are derived from the nix-darwin user
# (useGlobalPkgs), so they are NOT set here — same as home/linux.nix. Setting
# nixpkgs.* here would assert-fail under useGlobalPkgs, which is why the unfree
# allowlist lives in modules/darwin.nix instead.
{ pkgs, ... }:

{
  imports = [ ./default.nix ];

  # Release current at the first `darwin-rebuild switch` on the Mac. Do not
  # bump on upgrades.
  home.stateVersion = "26.05";

  # macOS builds of apps that nixpkgs makes for darwin. UTM is Mac-only;
  # xcodes is the CLI that installs/switches
  # full Xcode versions — Xcode itself is not nix-installable (see README
  # "Xcode"). vlc-bin is the darwin equivalent of vlc in home/linux.nix.
  # Firefox and WhatsApp are not in the base on macOS; a context adds them
  # (see docs/applications.md). Global apps live in home/default.nix.
  home.packages = with pkgs; [
    utm
    xcodes
    vlc-bin
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

}
