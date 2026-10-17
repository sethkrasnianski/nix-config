# Construct the public outputs and private context compositions through one path.
# Context flakes supply portable Home Manager modules and optional OS modules.
{ inputs }:
{
  target,
  contexts ? [ ],
  buildMetadata ? { },
}:
let
  inherit (inputs)
    nixpkgs
    home-manager
    nixos-wsl
    nix-darwin
    nix-homebrew
    ;
  lib = nixpkgs.lib;
  darwin = target == "macbook";
  system = if darwin then "aarch64-darwin" else "x86_64-linux";
  moduleKind = if darwin then "darwinModules" else "nixosModules";
  validTargets = [
    "nixos"
    "nixos-headless"
    "nixos-default"
    "macbook"
  ];
  homeModules = lib.concatMap (
    c: lib.optional (c.flake ? homeManagerModules.default) c.flake.homeManagerModules.default
  ) contexts;
  systemModules = lib.concatMap (
    c:
    lib.optional (builtins.hasAttr "default" (
      c.flake.${moduleKind} or { }
    )) c.flake.${moduleKind}.default
  ) contexts;
  loaded = map (c: builtins.removeAttrs c [ "flake" ]) contexts;
  commonModules = [
    ../modules/contexts.nix
    ../modules/local-agents.nix
    ../modules/local-llm.nix
    (import inputs.local-config.outPath)
    ({ config, lib, ... }: {
      contexts = {
        inherit target loaded;
        build = {
          baseRevision = inputs.self.rev or inputs.self.dirtyRev or "uncommitted";
        }
        // buildMetadata;
      };
      assertions = [
        {
          assertion =
            (homeModules == [ ] && !(lib.any (c: c.hasShell or false) contexts))
            || config.contexts.user != null;
          message = "Home Manager contexts and shells require contexts.user and a configured Home Manager user (nixos-default has no user by default).";
        }
      ];
      home-manager.users = lib.optionalAttrs (config.contexts.user != null) {
        ${config.contexts.user}.imports = homeModules;
      };
    })
  ];
  platformModules =
    if darwin then
      [
        home-manager.darwinModules.home-manager
        nix-homebrew.darwinModules.nix-homebrew
        ../modules/local-llm-darwin.nix
        ../hosts/macbook.nix
      ]
    else
      [
        home-manager.nixosModules.home-manager
        ../modules/local-llm-nixos.nix
      ]
      ++ (
        if target == "nixos-default" then
          [ ../hosts/nixos-default.nix ]
        else
          [
            nixos-wsl.nixosModules.default
            ../hosts/nixos-wsl.nix
          ]
      )
      ++ lib.optional (target == "nixos-headless") { local.graphical.enable = false; };
in
if !(builtins.elem target validTargets) then
  throw "Unknown nix-config target: ${target}"
else if darwin then
  nix-darwin.lib.darwinSystem { modules = commonModules ++ platformModules ++ systemModules; }
else
  nixpkgs.lib.nixosSystem {
    inherit system;
    modules = commonModules ++ platformModules ++ systemModules;
  }
