# WSL-specific configuration. Only imported by the WSL host; the nixos-wsl
# module itself (which provides the `wsl.*` options) is added in flake.nix.
{ ... }:

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
}
