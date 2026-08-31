# Evaluate the host-local OpenCode profile at startup. This intentionally
# imports only the profile modules, so changing model routing does not require
# rebuilding the system or Home Manager.
{
  localConfigPath ? null,
}:
let
  root = ../.;
  flake = builtins.getFlake (toString root);
  lib = flake.inputs.nixpkgs.lib;
  pkgs = import flake.inputs.nixpkgs { system = builtins.currentSystem; };
  localConfig =
    if localConfigPath != null && builtins.pathExists localConfigPath then
      import localConfigPath
    else
      { };
  evaluated = lib.evalModules {
    specialArgs = { inherit pkgs; };
    modules = [
      (
        { lib, ... }:
        {
          options.assertions = lib.mkOption {
            type = lib.types.listOf lib.types.attrs;
            default = [ ];
          };
          options.home-manager.extraSpecialArgs = lib.mkOption {
            type = lib.types.attrs;
            default = { };
          };
        }
      )
      (import (root + "/modules/local-agents.nix"))
      (import (root + "/modules/local-llm.nix"))
      localConfig
    ];
  };
  failures = builtins.filter (assertion: !assertion.assertion) evaluated.config.assertions;
in
if failures != [ ] then
  throw (
    "OpenCode local.nix assertions failed:\n"
    + builtins.concatStringsSep "\n" (map (assertion: assertion.message) failures)
  )
else
  {
    agents = evaluated.config.home-manager.extraSpecialArgs.localOpenCodeAgents;
    builtInAgents = evaluated.config.home-manager.extraSpecialArgs.localOpenCodeBuiltInAgents;
    ollama = evaluated.config.home-manager.extraSpecialArgs.localLlm;
  }
