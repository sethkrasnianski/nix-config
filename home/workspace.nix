# Context identities use conditional Git includes. More specific directories
# appear last. The base identity stays active outside those directories.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;
  profiles = lib.attrValues config.workspace.gitProfiles;
  ordered = lib.sort (
    a: b: builtins.stringLength a.directory < builtins.stringLength b.directory
  ) profiles;
  validDirectory =
    directory:
    directory != ""
    && !(lib.hasPrefix "/" directory)
    && lib.all (character: !(lib.hasInfix character directory)) [
      "*"
      "?"
      "["
      "]"
      "\\"
      "\n"
    ]
    && lib.all (part: part != ".." && part != "." && part != "") (lib.splitString "/" directory);
in
{
  options.workspace.gitProfiles = mkOption {
    default = { };
    description = "Git identities scoped to directories relative to this user's home.";
    type = types.attrsOf (
      types.submodule {
        options = {
          directory = mkOption { type = types.str; };
          name = mkOption {
            type = types.str;
            default = config.programs.git.settings.user.name;
          };
          email = mkOption { type = types.str; };
          signingKey = mkOption {
            type = types.nullOr types.str;
            default = null;
          };
          settings = mkOption {
            type = types.attrsOf types.anything;
            default = { };
          };
        };
      }
    );
  };
  config = {
    assertions = [
      {
        assertion = lib.all (p: validDirectory p.directory) profiles;
        message = "Git profile directories must be home-relative paths without glob characters, backslashes, newlines, or . and .. components.";
      }
      {
        assertion = lib.length (lib.unique (map (p: p.directory) profiles)) == lib.length profiles;
        message = "Git profile directories must be unique.";
      }
    ];
    programs.git.includes = map (p: {
      condition = "gitdir${lib.optionalString pkgs.stdenv.hostPlatform.isDarwin "/i"}:${config.home.homeDirectory}/${p.directory}/";
      contents = lib.recursiveUpdate p.settings {
        user = {
          inherit (p) name email;
        }
        // lib.optionalAttrs (p.signingKey != null) { inherit (p) signingKey; };
      };
    }) ordered;
  };
}
