# Ghostty terminal, managed declaratively. On the WSL host Ghostty runs as a
# Wayland GUI app through WSLg; WSLg mirrors the Windows clipboard into the
# Wayland clipboard automatically, so no clipboard bridge is needed here. On
# macOS the official binary bundle (ghostty-bin) is used — nixpkgs' source
# build is Linux-only — and home-manager links Ghostty.app into ~/Applications.
#
# The home-manager module owns ~/.config/ghostty/config and installs the
# package (so ghostty is dropped from home.packages in default.nix to avoid a
# duplicate). Config keys map to Ghostty's own names; see
# https://ghostty.org/docs/config/reference. Default paste binding is
# ctrl+shift+v (ctrl+v is added in a follow-up).
{ pkgs, ... }:

{
  programs.ghostty = {
    enable = true;
    package = if pkgs.stdenv.isDarwin then pkgs.ghostty-bin else pkgs.ghostty;

    # Bind ctrl+v to paste, alongside Ghostty's default ctrl+shift+v, so a
    # Windows-style paste works out of the box. This shadows readline's
    # verbatim-insert (quoted C-v) in the terminal; ctrl+shift+v still pastes
    # too. Multi-line pastes still hit clipboard-paste-protection's confirm
    # prompt (Ghostty's default) — that guard is left on.
    settings.keybind = [
      "ctrl+v=paste_from_clipboard"
    ];
  };
}
