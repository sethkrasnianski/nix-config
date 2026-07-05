# WSL-specific configuration. Only imported by the WSL host; the nixos-wsl
# module itself (which provides the `wsl.*` options) is added in flake.nix.
# nixpkgs-stable comes from flake.nix via specialArgs.
{ lib, nixpkgs-stable, ... }:

let
  flakePath = "/home/nixos/oss/nixos-config";
in
{
  wsl.enable = true;
  wsl.defaultUser = "nixos";
  # wsl.wslg.enable = true;

  # NixOS-WSL defaults wheel to passwordless sudo. This host runs agent CLIs
  # that execute shell commands, so keep the password prompt as a tripwire
  # against unattended privilege escalation. Requires the user to have a
  # password — users are mutable here, so set it once with `passwd` (it
  # survives rebuilds). Recovery if locked out: `wsl -u root` from Windows.
  security.sudo.wheelNeedsPassword = lib.mkForce true;

  # opencode from nixos-unstable segfaults at startup under WSL2 — the crash
  # is in glibc's ld.so while it loads the Bun-compiled binary
  # (https://github.com/anomalyco/opencode/issues/26846). The nixos-25.11
  # build works, so swap it in here until unstable is fixed.
  nixpkgs.overlays = [
    (final: prev: {
      opencode = nixpkgs-stable.legacyPackages.${prev.stdenv.hostPlatform.system}.opencode;
    })
  ];

  # GNOME pulls in NetworkManager, whose module unconditionally enables the
  # wpa_supplicant service for its wifi backend. WSL has no wifi hardware and
  # the unit fails at startup (226/NAMESPACE), so force it off here.
  networking.wireless.enable = lib.mkForce false;

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
