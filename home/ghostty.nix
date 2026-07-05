# Ghostty terminal, managed declaratively. Ghostty runs as a Wayland GUI app
# through WSLg on the WSL host; WSLg mirrors the Windows clipboard into the
# Wayland clipboard automatically, so no clipboard bridge is needed here.
#
# The home-manager module owns ~/.config/ghostty/config and installs the
# package (so ghostty is dropped from home.packages in default.nix to avoid a
# duplicate). Config keys map to Ghostty's own names; see
# https://ghostty.org/docs/config/reference. Default paste binding is
# ctrl+shift+v (ctrl+v is added in a follow-up).
{ ... }:

{
  programs.ghostty.enable = true;
}
