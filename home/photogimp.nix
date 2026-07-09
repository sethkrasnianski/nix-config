# PhotoGIMP (github.com/Diolinux/PhotoGIMP) reskins GIMP's UI, shortcuts and
# tool layout to feel like Photoshop. It's not a package — just a set of files
# that overlay GIMP's user config dir. GIMP rewrites most of those files at
# runtime (sessionrc, shortcutsrc, window layout), so a read-only store
# symlink would fight GIMP on every save; instead this seeds the config dir
# from a pinned, hash-verified release **once** per PhotoGIMP version via a
# home-manager activation script. After seeding, GIMP owns the directory and
# your in-app tweaks persist across rebuilds.
#
# To pull a newer PhotoGIMP release: bump `version` to the new release tag,
# then refresh both hashes — set one to lib.fakeHash, run `rebuild`, and copy
# the "got:" hash from the mismatch error (repeat for the other platform's
# zip, cross-building isn't required since fetchzip only needs network
# access). Bumping the version re-seeds and overwrites the PhotoGIMP-managed
# files, discarding customizations made since the last bump.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  version = "3.0";
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;

  photogimp = pkgs.fetchzip {
    url = "https://github.com/Diolinux/PhotoGIMP/releases/download/${version}/${
      if isDarwin then "PhotoGIMP.zip" else "PhotoGIMP-linux.zip"
    }";
    hash =
      if isDarwin then
        "sha256-r+nwyf7erpYJqq5pyQd1Smbu/KRIbWrJ3hu7mnTuoY8="
      else
        "sha256-g7JNSr6LczV0uHvy5UjRwDwVkWTGMFRd0bW9RaBoDjM=";
  };

  # The Linux zip nests the config under .config/GIMP/3.0/ (it also ships a
  # .local/share/ with a flatpak-specific desktop entry — deliberately not
  # used here, since it would shadow the nixpkgs-installed launcher with a
  # broken Exec line). The macOS zip's root IS the 3.0 folder, so fetchzip's
  # default stripRoot already lands there.
  photogimpSrc = if isDarwin then photogimp else "${photogimp}/.config/GIMP/3.0";

  # GIMP's user dir is versioned by major.minor (GIMP_USER_VERSION), not the
  # PhotoGIMP release tag — pinned nixpkgs ships GIMP 3.2.
  gimpUserDir = if isDarwin then "Library/Application Support/GIMP/3.2" else ".config/GIMP/3.2";
in
{
  home.activation.photogimp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    photogimpDir="${config.home.homeDirectory}/${gimpUserDir}"
    marker="$photogimpDir/.photogimp-version"
    if [ ! -e "$marker" ] || [ "$(cat "$marker")" != "${version}" ]; then
      run mkdir -p "$photogimpDir"
      run cp -r "${photogimpSrc}/." "$photogimpDir/"
      run chmod -R u+w "$photogimpDir"
      run --quiet sh -c "printf '%s\n' '${version}' > \"$marker\""
    fi
  '';
}
