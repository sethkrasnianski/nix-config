# Optional host-local Ollama service and OpenCode routing profile.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.local.llm;
in
{
  options.local.llm = {
    enable = lib.mkEnableOption "local Ollama support for selected OpenCode agents";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.ollama;
      description = "Ollama package, selected for the host's hardware backend.";
    };

    model = lib.mkOption {
      type = lib.types.str;
      default = "qwen3-coder:30b";
    };

    contextLength = lib.mkOption {
      type = lib.types.ints.positive;
      default = 65536;
      description = "Ollama context length; OpenCode requires at least 65536.";
    };

    kvCacheType = lib.mkOption {
      type = lib.types.enum [
        "f16"
        "q8_0"
        "q4_0"
      ];
      default = "q8_0";
    };

    parallelRequests = lib.mkOption {
      type = lib.types.ints.positive;
      default = 1;
    };

    maxLoadedModels = lib.mkOption {
      type = lib.types.ints.positive;
      default = 1;
    };

    keepAlive = lib.mkOption {
      type = lib.types.str;
      default = "5m";
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional Ollama environment variables.";
    };
  };

  config = {
    home-manager.extraSpecialArgs.localLlm = {
      enable = cfg.enable;
      inherit (cfg) model contextLength;
    };
  };
}
