# Generate folder environments from the same locked composition as the system.
# The helper checks ownership before activation and never replaces user files.
{
  config,
  lib,
  pkgs,
  nixConfigContexts ? [ ],
  ...
}:
let
  specifications = pkgs.writeText "context-envrcs.json" (
    builtins.toJSON (
      map (c: {
        inherit (c) name directory;
        flake = c.shell;
      }) (builtins.filter (c: c.hasShell) nixConfigContexts)
    )
  );
  command = "${pkgs.python3}/bin/python3 ${../scripts/context_envrcs.py} --home ${lib.escapeShellArg config.home.homeDirectory} --state ${lib.escapeShellArg "${config.xdg.stateHome}/nix-config/context-envrcs.json"} --spec ${specifications} --direnv ${pkgs.direnv}/bin/direnv";
in
{
  home.activation.checkContextEnvrcs = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
    ${command} --check
  '';
  home.activation.contextEnvrcs = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${command}
  '';
}
