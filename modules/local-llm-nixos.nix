# NixOS-specific Ollama service wiring for the shared local LLM options.
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
  }
  // cfg.extraEnvironment;
in
{
  config = lib.mkIf cfg.enable {
    services.ollama = {
      enable = true;
      package = cfg.package;
      host = "127.0.0.1";
      port = 11434;
      inherit environmentVariables;
    };
  };
}
