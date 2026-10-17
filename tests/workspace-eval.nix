# Export the actual include definitions for Git's integration tests.
let
  flake = builtins.getFlake (toString ../.);
  host = flake.lib.mkHost {
    target = "nixos-headless";
    contexts = [
      {
        name = "work";
        path = "/unused/config";
        directory = "Work";
        revision = "test";
        flake.homeManagerModules.default = {
          workspace.gitProfiles.work = {
            directory = "Work";
            email = "work@users.noreply.github.com";
          };
          workspace.gitProfiles.client = {
            directory = "Work/Client";
            email = "client@users.noreply.github.com";
          };
        };
      }
    ];
  };
in
{
  base = host.config.home-manager.users.nixos.programs.git.settings.user;
  includes = host.config.home-manager.users.nixos.programs.git.includes;
}
