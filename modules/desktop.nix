# GNOME desktop, gated behind `local.graphical.enable` (default: true).
#
# When disabled the host is headless: no desktop environment or display
# manager. Individual GUI apps still work (e.g. Ghostty via WSLg), since those
# are plain packages in modules/common.nix and don't need a desktop.
{ config, lib, ... }:

let
  cfg = config.local.graphical;
in
{
  options.local.graphical.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Enable the GNOME graphical desktop (with GDM).";
  };

  config = lib.mkIf cfg.enable {
    services.xserver.enable = true;

    # GNOME with the GDM display manager.
    services.displayManager.gdm.enable = true;
    services.desktopManager.gnome.enable = true;

    # Keyboard layout for X.
    services.xserver.xkb.layout = "us";
  };
}
