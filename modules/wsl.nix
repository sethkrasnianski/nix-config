# WSL-specific configuration. Only imported by the WSL host; the nixos-wsl
# module itself (which provides the `wsl.*` options) is added in flake.nix.
{ ... }:

let
  flakePath = "/home/nixos/personal/nixos-config";
in
{
  wsl.enable = true;
  wsl.defaultUser = "nixos";
  # wsl.wslg.enable = true;

  # Terminals used with this host (Windows Terminal, Ghostty) support 24-bit
  # color but do not all advertise it. COLORTERM makes TUI apps (e.g.
  # `emacs -nw`) render truecolor instead of approximating the theme with
  # the 256-color palette.
  environment.variables.COLORTERM = "truecolor";

  # NOTE: no DISPLAY override here. WSLg provides a local X socket
  # (/tmp/.X11-unix/X0, DISPLAY=:0) and GUI apps like Ghostty use it directly.
  # The old `DISPLAY = "<host-ip>:0.0"` pattern is for a Windows-side X server
  # (VcXsrv) and breaks WSLg apps when none is running.

  # Shortcuts to rebuild this WSL host in either mode. Both aliases exist in
  # both builds, so you can always flip back (e.g. run `rebuild` while headless).
  environment.shellAliases = {
    rebuild = "sudo nixos-rebuild switch --flake ${flakePath}#nixos";
    rebuild-headless = "sudo nixos-rebuild switch --flake ${flakePath}#nixos-headless";
  };
}
