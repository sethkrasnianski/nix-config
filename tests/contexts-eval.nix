# Exercise the real host factory with portable and platform-specific modules.
let
  flake = builtins.getFlake (toString ../.);
  context = {
    name = "fixture";
    path = "/unused/fixture/config";
    directory = "Work";
    revision = "fixture";
    flake = {
      homeManagerModules.default = {
        home.sessionVariables.CONTEXT_FIXTURE = "portable";
        workspace.gitProfiles.work = {
          directory = "Work";
          email = "work@users.noreply.github.com";
        };
        workspace.gitProfiles.client = {
          directory = "Work/Client";
          email = "client@users.noreply.github.com";
        };
      };
      nixosModules.default = {
        environment.variables.CONTEXT_OS = "linux";
      };
      darwinModules.default = {
        environment.variables.CONTEXT_OS = "darwin";
      };
    };
  };
  linux = flake.lib.mkHost {
    target = "nixos-headless";
    contexts = [ context ];
  };
  mac = flake.lib.mkHost {
    target = "macbook";
    contexts = [ context ];
  };
  native = flake.lib.mkHost {
    target = "nixos-default";
    contexts = [ (context // { flake = { inherit (context.flake) nixosModules; }; }) ];
  };
in
assert linux.config.home-manager.users.nixos.home.sessionVariables.CONTEXT_FIXTURE == "portable";
assert
  mac.config.home-manager.users.${mac.config.local.primaryUser}.home.sessionVariables.CONTEXT_FIXTURE
  == "portable";
assert linux.config.environment.variables.CONTEXT_OS == "linux";
assert mac.config.environment.variables.CONTEXT_OS == "darwin";
assert native.config.contexts.user == null;
assert
  !(builtins.tryEval (
    (flake.lib.mkHost {
      target = "nixos-default";
      contexts = [ context ];
    }).config.system.build.toplevel.drvPath
  )).success;
assert
  (builtins.head linux.config.home-manager.users.nixos.programs.git.includes).condition
  == "gitdir:/home/nixos/Work/";
assert
  (builtins.head mac.config.home-manager.users.${mac.config.local.primaryUser}.programs.git.includes)
  .condition == "gitdir/i:/Users/${mac.config.local.primaryUser}/Work/";
assert !(builtins.tryEval (flake.lib.mkHost { target = "invalid"; })).success;
{
  linux = linux.config.system.build.toplevel.drvPath;
  mac = mac.system.drvPath;
  native = native.config.system.build.toplevel.drvPath;
}
