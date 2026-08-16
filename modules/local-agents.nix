# Repository-owned OpenCode inference profiles with host-local provider selection.
{ config, lib, ... }:

let
  defaults = import ../opencode/agent-defaults.nix;
  inferenceFields = {
    model = lib.types.nullOr lib.types.str;
    reasoningEffort = lib.types.nullOr (
      lib.types.enum [
        "low"
        "medium"
        "high"
        "xhigh"
        "max"
      ]
    );
    variant = lib.types.nullOr lib.types.str;
    temperature = lib.types.nullOr lib.types.float;
    top_p = lib.types.nullOr lib.types.float;
  };
  agentProfileType = lib.types.attrsOf (
    lib.types.submodule (
      { ... }: {
        options = lib.mapAttrs (
          _: type:
          lib.mkOption {
            inherit type;
            default = null;
          }
        ) inferenceFields;
      }
    )
  );
  defaultProfiles = lib.mapAttrs (
    _: agents:
    lib.mapAttrs (
      _: values:
      lib.mapAttrs (_: value: lib.mkDefault value) (
        {
          model = values.model;
          reasoningEffort = values.reasoningEffort;
        }
        // {
          variant = null;
          temperature = null;
          top_p = null;
        }
      )
    ) agents
  ) defaults;
  selectedAgents =
    config.local.opencode.agents.providers.${config.local.opencode.agents.provider} or { };
  builtInAgentSettings = {
    build = config.local.opencode.build;
    plan = config.local.opencode.plan;
  };
  builtInAgents = lib.filterAttrs (_: settings: settings != { }) (
    lib.mapAttrs (_: settings: lib.filterAttrs (_: value: value != null) settings) builtInAgentSettings
  );
  profileAssertions = lib.concatLists (
    lib.mapAttrsToList (
      providerName: profile:
      (lib.optional (lib.hasAttr "build" profile) {
        assertion = false;
        message = "local.opencode.agents.providers.${providerName}.build is reserved for OpenCode's built-in Build agent; set local.opencode.build instead";
      })
      ++ (lib.optional (lib.hasAttr "plan" profile) {
        assertion = false;
        message = "local.opencode.agents.providers.${providerName}.plan is reserved for OpenCode's built-in Plan agent; set local.opencode.plan instead";
      })
    ) config.local.opencode.agents.providers
  );
in
{
  options.local.opencode = {
    build = {
      model = lib.mkOption {
        type = inferenceFields.model;
        default = null;
        description = "Host-local model override for OpenCode's built-in Build agent.";
      };
      reasoningEffort = lib.mkOption {
        type = inferenceFields.reasoningEffort;
        default = null;
        description = "Host-local reasoning effort override for OpenCode's built-in Build agent.";
      };
    };
    plan = {
      model = lib.mkOption {
        type = inferenceFields.model;
        default = null;
        description = "Host-local model override for OpenCode's built-in Plan agent.";
      };
      reasoningEffort = lib.mkOption {
        type = inferenceFields.reasoningEffort;
        default = null;
        description = "Host-local reasoning effort override for OpenCode's built-in Plan agent.";
      };
    };
  };

  options.local.opencode.agents = {
    provider = lib.mkOption {
      type = lib.types.str;
      default = "github-copilot";
      description = "Profile key used for OpenCode agent inference settings, not an OpenCode provider declaration.";
    };
    providers = lib.mkOption {
      type = lib.types.attrsOf agentProfileType;
      default = { };
      description = "Host-local per-profile OpenCode agent inference overrides.";
    };
  };

  config = {
    local.opencode.agents.providers = defaultProfiles;

    assertions = lib.flatten (
      [
        {
          assertion = lib.hasAttr config.local.opencode.agents.provider config.local.opencode.agents.providers;
          message = "local.opencode.agents.provider must name a configured provider profile";
        }
      ]
      ++ profileAssertions
      ++ lib.mapAttrsToList (
        name: agent:
        lib.optional (agent.model != null && lib.hasPrefix "ollama/" agent.model) {
          assertion = config.local.llm.enable;
          message = "local.opencode.agents.providers.${config.local.opencode.agents.provider}.${name}.model requires local.llm.enable = true";
        }
        ++ lib.optional (agent.model != null && lib.hasPrefix "ollama/" agent.model) {
          assertion = config.local.llm.model == lib.removePrefix "ollama/" agent.model;
          message = "local.opencode.agents.providers.${config.local.opencode.agents.provider}.${name}.model must match local.llm.model after the ollama/ prefix";
        }
      ) selectedAgents
      ++ lib.mapAttrsToList (
        name: settings:
        lib.optional (settings.model != null && lib.hasPrefix "ollama/" settings.model) {
          assertion = config.local.llm.enable;
          message = "local.opencode.${name}.model requires local.llm.enable = true";
        }
        ++ lib.optional (settings.model != null && lib.hasPrefix "ollama/" settings.model) {
          assertion = config.local.llm.model == lib.removePrefix "ollama/" settings.model;
          message = "local.opencode.${name}.model must match local.llm.model after the ollama/ prefix";
        }
      ) builtInAgentSettings
    );

    home-manager.extraSpecialArgs.localOpenCodeAgents = selectedAgents;
    home-manager.extraSpecialArgs.localOpenCodeBuiltInAgents = builtInAgents;
  };
}
