# macOS host — the nix-darwin system for the Mac (darwinConfigurations.macbook).
# Mirrors hosts/nixos-wsl.nix: this is where the per-machine facts live
# (username, hostPlatform, stateVersion, home-manager wiring). Shared darwin
# system config is in modules/darwin.nix.
{ ... }:

let
  # CHANGE ME if the macOS account name differs — the single place the
  # username is defined; everything else derives from it.
  username = "sethkrasnianski";
in
{
  imports = [ ../modules/darwin.nix ];

  # Apple Silicon. Also pins the package set nix-darwin and home-manager
  # evaluate against (so darwinSystem needs no explicit `system` argument).
  nixpkgs.hostPlatform = "aarch64-darwin";

  # nix-darwin needs the account declared so home-manager can resolve its home
  # directory; home.username / home.homeDirectory derive from this (which is
  # why home/darwin.nix sets neither, same as home/linux.nix).
  users.users.${username}.home = "/Users/${username}";

  # nix-homebrew owns the Homebrew installation and must run as this user
  # (the module itself is enabled in modules/darwin.nix).
  nix-homebrew.user = username;

  # System activation runs as root; options that act on a user (Homebrew,
  # defaults, ...) apply to this one. Required once homebrew.enable is set.
  system.primaryUser = username;

  # Per-user config (dotfiles, user packages, shells) — see home/ at the repo
  # root. darwin.nix is the macOS home entrypoint; it carries the per-machine
  # home.stateVersion. Mirrors modules/common.nix's home-manager wiring.
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-bak";
    users.${username} = import ../home/darwin.nix;
  };

  # Release nix-darwin state was first created with. Do not bump on upgrades.
  system.stateVersion = 6;
}
