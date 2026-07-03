# direnv: per-directory environments from .envrc files. Hooks into the
# home-manager-managed bash and zsh automatically.
{ ... }:

{
  programs.direnv = {
    enable = true;
    # Cached `use nix` / `use flake` — avoids re-evaluating on every cd and
    # keeps dev shells alive across garbage collection.
    nix-direnv.enable = true;
  };
}
