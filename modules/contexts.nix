# Context metadata belongs to the system generation so status survives rollbacks.
# The CLI discovers repositories. Evaluation consumes only explicit flake inputs.
{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.contexts;
  contextType = types.submodule {
    options = {
      name = mkOption { type = types.strMatching "[a-z][a-z0-9-]*"; };
      path = mkOption { type = types.str; };
      directory = mkOption { type = types.str; };
      revision = mkOption { type = types.str; };
      sourceHash = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      dirty = mkOption {
        type = types.bool;
        default = false;
      };
      hasShell = mkOption {
        type = types.bool;
        default = false;
      };
      shell = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
    };
  };
in
{
  options.contexts = {
    user = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Home Manager user that receives context configuration.";
    };
    target = mkOption {
      type = types.str;
      internal = true;
    };
    loaded = mkOption {
      type = types.listOf contextType;
      default = [ ];
      internal = true;
    };
    build = mkOption {
      type = types.attrs;
      default = { };
      internal = true;
    };
    manifest = mkOption {
      type = types.attrs;
      readOnly = true;
      internal = true;
      default = cfg.build // {
        version = 1;
        inherit (cfg) target;
        contexts = cfg.loaded;
      };
    };
  };
  config = {
    assertions = [
      {
        assertion = lib.length (lib.unique (map (c: c.name) cfg.loaded)) == lib.length cfg.loaded;
        message = "Context names must be unique within a composition.";
      }
      {
        assertion = lib.all (
          c:
          c.directory != ""
          && !(lib.hasPrefix "/" c.directory)
          && lib.all (part: part != ".." && part != ".") (lib.splitString "/" c.directory)
        ) cfg.loaded;
        message = "Context directories must be nonempty paths relative to the user's home, without . or .. components.";
      }
    ];
    environment.etc."nix-config/manifest.json".text = builtins.toJSON cfg.manifest;
    home-manager.extraSpecialArgs = {
      nixConfigTarget = cfg.target;
      nixConfigContexts = cfg.loaded;
    };
  };
}
