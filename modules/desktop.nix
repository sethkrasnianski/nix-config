# GNOME desktop (with GDM), shared by both hosts.
{ ... }:

{
  services.xserver.enable = true;

  # GNOME with the GDM display manager.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Keyboard layout for X.
  services.xserver.xkb.layout = "us";
}
