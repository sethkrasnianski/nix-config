# direnv: per-directory environments from .envrc files. Hooks into the
# home-manager-managed bash and zsh automatically. devenv is installed
# alongside because devenv-based projects' .envrc files call the CLI directly
# (`eval "$(devenv direnvrc)"` then `use devenv`) and fail without it.
{ pkgs, ... }:

{
  programs.direnv = {
    enable = true;
    # Cached `use nix` / `use flake` — avoids re-evaluating on every cd and
    # keeps dev shells alive across garbage collection.
    nix-direnv.enable = true;
  };

  home.packages = [ pkgs.devenv ];
}
