# Install the pinned Synergy 3 app at /Applications/Synergy.app on the Mac.
# Synergy hardcodes that path: its service symlinks synergy-core into
# PrivilegedHelperTools from /Applications/Synergy.app, so a copy under
# ~/Applications (Home Manager) or /Applications/Nix Apps (nix-darwin) never
# finishes setting itself up. Its directory watcher also uninstalls the service
# whenever /Applications/Synergy.app is renamed or removed, so activation only
# replaces the bundle when the pinned build actually changed.
{ lib, pkgs, ... }:

{
  system.activationScripts.postActivation.text = lib.mkAfter ''
    src=${pkgs.synergy3}/Applications/Synergy.app
    dst=/Applications/Synergy.app
    # The signed main executable embeds the code directory hash, so it
    # identifies the build.
    if ! /usr/bin/cmp -s "$src/Contents/MacOS/Synergy" "$dst/Contents/MacOS/Synergy"; then
      echo "Installing Synergy 3 to $dst..."
      tmp=/Applications/.Synergy.app.tmp
      rm -rf "$tmp"
      /usr/bin/ditto "$src" "$tmp"
      chmod -R u+w "$tmp"
      rm -rf "$dst"
      mv "$tmp" "$dst"
      echo "Relaunch Synergy so it re-registers its background service."
    fi
  '';
}
