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
in
{
  options.local.opencode.agents = {
    provider = lib.mkOption {
      type = lib.types.str;
      default = "github-copilot";
      description = "Provider profile used for OpenCode agent inference settings.";
    };
    providers = lib.mkOption {
      type = lib.types.attrsOf agentProfileType;
      default = { };
      description = "Host-local per-provider OpenCode agent inference profiles.";
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
    );

    home-manager.extraSpecialArgs.localOpenCodeAgents = selectedAgents;
  };
}
