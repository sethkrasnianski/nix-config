# nix-darwin-specific Ollama launchd wiring for the shared local LLM options.
{ config, lib, ... }:

let
  cfg = config.local.llm;
  environmentVariables = {
    OLLAMA_CONTEXT_LENGTH = toString cfg.contextLength;
    OLLAMA_KV_CACHE_TYPE = cfg.kvCacheType;
    OLLAMA_NUM_PARALLEL = toString cfg.parallelRequests;
    OLLAMA_MAX_LOADED_MODELS = toString cfg.maxLoadedModels;
    OLLAMA_KEEP_ALIVE = cfg.keepAlive;
    OLLAMA_NO_CLOUD = "1";
    OLLAMA_HOST = "127.0.0.1:11434";
  }
  // cfg.extraEnvironment;
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    launchd.user.agents.ollama = {
      serviceConfig = {
        ProgramArguments = [
          "${cfg.package}/bin/ollama"
          "serve"
        ];
        EnvironmentVariables = environmentVariables;
        RunAtLoad = true;
        KeepAlive = true;
      };
    };
  };
}
