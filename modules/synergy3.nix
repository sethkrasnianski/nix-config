# Install the pinned Synergy Flatpak on NixOS hosts. Flatpak owns the app's
# runtime and desktop exports; activation applies accepted version/hash updates
# during the next rebuild, including on hosts without a Home Manager user.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  pinned = import ../pkgs/synergy3/pinned.nix;
  fileName = "synergy-${pinned.version}-linux-noble-x86_64.flatpak";
in
{
  services.flatpak.enable = true;

  # The Flatpak module requires portals even on the headless WSL output. GNOME
  # supplies its portal implementation on graphical hosts; headless hosts simply
  # have no graphical session in which to launch the app.
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  xdg.portal.config.common.default = lib.mkDefault "gtk";

  system.activationScripts.synergy3 = {
    text = ''
      flatpak=${config.services.flatpak.package}/bin/flatpak
      bundle=${pkgs.synergy3}/share/synergy3/${fileName}
      bundle_store_path=${pkgs.synergy3}
      marker=/var/lib/nixos/synergy3-bundle-store-path
      synergy_ref=app/com.symless.synergy/x86_64/master

      "$flatpak" remote-add --system --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo

      installed_refs=$("$flatpak" list --system --app --columns=ref)
      if ! printf '%s\n' "$installed_refs" | grep -Fxq "$synergy_ref" \
        || [ "$(cat "$marker" 2>/dev/null || true)" != "$bundle_store_path" ]; then
        mkdir -p /var/lib/nixos
        "$flatpak" install --system --noninteractive --assumeyes --reinstall \
          --bundle "$bundle"
        printf '%s\n' "$bundle_store_path" > "$marker"
      fi
    '';
  };
}
