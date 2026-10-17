# Package the context CLI with its runtime tools. The source checkout remains
# editable, while each invocation uses a store-backed CLI and scaffold template.
{
  config,
  pkgs,
  nixConfigTarget,
  ...
}:
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "config";
      runtimeInputs = [
        pkgs.python3
        pkgs.git
        pkgs.nix
      ];
      text = ''
        export NIX_CONFIG_REPO_DEFAULT=${pkgs.lib.escapeShellArg "${config.home.homeDirectory}/oss/nix-config"}
        export NIX_CONFIG_DEFAULT_TARGET=${pkgs.lib.escapeShellArg nixConfigTarget}
        export NIX_CONFIG_TEMPLATE=${../contexts/template}
        export NIX_CONFIG_ENVRC_HELPER=${../scripts/context_envrcs.py}
        exec python3 ${../scripts/config.py} "$@"
      '';
    })
  ];
  home.shellAliases = {
    rebuild = "config rebuild --target ${nixConfigTarget}";
  }
  //
    pkgs.lib.optionalAttrs
      (builtins.elem nixConfigTarget [
        "nixos"
        "nixos-headless"
      ])
      {
        rebuild-headless = "config rebuild --target nixos-headless";
        rebuild = "config rebuild --target nixos";
      };
}
