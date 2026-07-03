# Emacs + Doom. The editor itself is declarative; Doom manages its own
# packages with straight.el, so the framework is bootstrapped imperatively
# once (see the README "Emacs (Doom)" section):
#
#   git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.config/emacs
#   doom install
#
# The private Doom config (init.el / config.el / packages.el) lives in doom/
# at this repo's root; the WSL host symlinks ~/.config/doom to it
# (hosts/nixos-wsl.nix) so Doom picks up exactly those files. Doom's external
# tools (git, ripgrep, fd) are already provided by common.nix.
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # `emacs` tracks the newest release in nixpkgs (30.2 as of this writing),
    # unlike a version-pinned attribute such as `emacs30`.
    emacs

    # Doom module dependencies (flagged by `doom doctor`):
    nodejs # :tools lsp server auto-install
    shellcheck # :lang sh linting
    claude-agent-acp # Claude ACP adapter for agent-shell (see doom/config.el)
  ];

  # Icon font used by Doom's UI (modeline, treemacs, dashboard).
  fonts.packages = [ pkgs.nerd-fonts.symbols-only ];

  # Doom's CLI (`doom sync`, `doom doctor`, ...) lives inside the framework
  # checkout, which isn't a Nix package — put it on PATH for all shells.
  environment.shellInit = ''
    export PATH="$HOME/.config/emacs/bin:$PATH"
  '';
}
