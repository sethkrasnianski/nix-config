let
  root = ../..;
  flake = builtins.getFlake (toString root);
  lib = flake.inputs.nixpkgs.lib;
  system = "x86_64-linux";
  pkgs = import flake.inputs.nixpkgs { inherit system; };

  evalLocalAgents =
    modules:
    lib.evalModules {
      modules = [
        (
          { lib, ... }:
          {
            options = {
              assertions = lib.mkOption {
                type = lib.types.listOf lib.types.attrs;
                default = [ ];
              };
              home-manager.extraSpecialArgs = lib.mkOption {
                type = lib.types.attrs;
                default = { };
              };
              local.llm.enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
              };
              local.llm.model = lib.mkOption {
                type = lib.types.str;
                default = "test-model";
              };
            };
          }
        )
        (import (root + "/modules/local-agents.nix"))
      ]
      ++ modules;
    };

  selected = evalLocalAgents [
    {
      local.opencode = {
        build = {
          model = "test/build";
          reasoningEffort = "high";
        };
        plan = {
          model = "test/plan";
          reasoningEffort = "xhigh";
        };
      };
      local.opencode.agents = {
        provider = "test-profile";
        providers."test-profile".selected = {
          model = "test/custom";
          reasoningEffort = "high";
        };
      };
    }
  ];
  selectedBuiltInAgents = selected.config.home-manager.extraSpecialArgs.localOpenCodeBuiltInAgents;
  selectedAgents = selected.config.home-manager.extraSpecialArgs.localOpenCodeAgents;
  partial = evalLocalAgents [
    {
      local.opencode.build.model = "test/build";
    }
  ];
  partialBuiltInAgents = partial.config.home-manager.extraSpecialArgs.localOpenCodeBuiltInAgents;
  empty = evalLocalAgents [ ];
  emptyBuiltInAgents = empty.config.home-manager.extraSpecialArgs.localOpenCodeBuiltInAgents;
  home =
    (flake.inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        (import (root + "/home/default.nix"))
        {
          home.username = "test";
          home.homeDirectory = "/tmp/nixos-config-local-agents-test";
          home.stateVersion = "25.11";
        }
      ];
      extraSpecialArgs = {
        localOpenCodeAgents = selectedAgents;
        localOpenCodeBuiltInAgents = selectedBuiltInAgents;
        localLlm = {
          enable = false;
        };
      };
    }).config;
  generated = builtins.fromJSON home.home.file.".config/opencode/local-agents.json".text;
  rejected = evalLocalAgents [
    {
      local.opencode.agents = {
        provider = "test-profile";
        providers."test-profile" = {
          build = {
            model = "test/build";
          };
          plan = {
            model = "test/plan";
          };
        };
      };
    }
  ];
  rejectedAssertions = builtins.filter (assertion: !assertion.assertion) rejected.config.assertions;
in
assert selected.config.local.opencode.build.model == "test/build";
assert selected.config.local.opencode.build.reasoningEffort == "high";
assert selected.config.local.opencode.plan.model == "test/plan";
assert selected.config.local.opencode.plan.reasoningEffort == "xhigh";
assert
  selectedBuiltInAgents == {
    build = {
      model = "test/build";
      reasoningEffort = "high";
    };
    plan = {
      model = "test/plan";
      reasoningEffort = "xhigh";
    };
  };
assert selectedAgents.selected.model == "test/custom";
assert selectedAgents.selected.reasoningEffort == "high";
assert
  partialBuiltInAgents == {
    build = {
      model = "test/build";
    };
  };
assert emptyBuiltInAgents == { };
assert generated.builtInAgents == selectedBuiltInAgents;
assert generated.agents == selectedAgents;
assert builtins.length rejectedAssertions == 2;
assert builtins.any (
  assertion: lib.hasInfix "local.opencode.build" assertion.message
) rejectedAssertions;
assert builtins.any (
  assertion: lib.hasInfix "local.opencode.plan" assertion.message
) rejectedAssertions;
"local agents evaluation tests passed"
