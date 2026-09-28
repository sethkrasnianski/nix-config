{
  stdenvNoCC,
  lib,
  undmg,
  curl,
  cacert,
  perl,
}:

let
  pinned = import ./pinned.nix;
  linuxFileName = "synergy-${pinned.version}-linux-noble-x86_64.flatpak";
  macosFileName = "synergy-${pinned.version}-macos-arm64.dmg";

  fetchInstaller = import ./fetch-installer.nix {
    inherit
      stdenvNoCC
      curl
      cacert
      perl
      ;
  };

  linuxInstaller = fetchInstaller {
    inherit (pinned) version;
    platform = "flatpak";
    fileName = linuxFileName;
    hash = pinned.linuxX86_64Hash;
  };

  macosInstaller = fetchInstaller {
    inherit (pinned) version;
    platform = "mac";
    fileName = macosFileName;
    hash = pinned.macosAarch64Hash;
  };

  linuxPackage = stdenvNoCC.mkDerivation {
    pname = "synergy3";
    inherit (pinned) version;
    src = linuxInstaller;
    dontUnpack = true;

    installPhase = ''
      runHook preInstall
      install -D -m 0444 "$src" "$out/share/synergy3/${linuxFileName}"
      runHook postInstall
    '';

    # The scheduled updater builds these on Linux to validate both artifacts,
    # including extracting the macOS app bundle without a Darwin builder.
    passthru = {
      inherit linuxInstaller macosInstaller macosPackage;
    };

    meta = {
      description = "Synergy 3 keyboard and mouse sharing application (Flatpak bundle)";
      homepage = "https://symless.com/synergy";
      license = lib.licenses.unfree;
      platforms = [ "x86_64-linux" ];
    };
  };

  macosPackage = stdenvNoCC.mkDerivation {
    pname = "synergy3";
    inherit (pinned) version;
    src = macosInstaller;
    nativeBuildInputs = [ undmg ];
    sourceRoot = ".";
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      app="$(find . -maxdepth 3 -type d -name 'Synergy.app' -print -quit)"
      if [ -z "$app" ]; then
        echo "The Synergy DMG did not contain Synergy.app" >&2
        exit 1
      fi

      mkdir -p "$out/Applications"
      cp -R "$app" "$out/Applications/Synergy.app"

      runHook postInstall
    '';

    passthru = {
      inherit linuxInstaller macosInstaller;
    };

    meta = {
      description = "Synergy 3 keyboard and mouse sharing application";
      homepage = "https://symless.com/synergy";
      license = lib.licenses.unfree;
      platforms = [ "aarch64-darwin" ];
    };
  };
in
if stdenvNoCC.hostPlatform.system == "aarch64-darwin" then
  macosPackage
else if stdenvNoCC.hostPlatform.system == "x86_64-linux" then
  linuxPackage
else
  throw "Synergy 3 is only packaged for x86_64-linux and aarch64-darwin"
