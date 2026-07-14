# WSL-specific configuration. Only imported by the WSL host; the nixos-wsl
# module itself (which provides the `wsl.*` options) is added in flake.nix.
{ lib, ... }:

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
  # (https://github.com/anomalyco/opencode/issues/26846, root cause in
  # nixpkgs' bun: https://github.com/NixOS/nixpkgs/issues/520383). Re-running
  # patchelf on the finished binary rewrites the ELF layout cleanly and fixes
  # the load (verified on 1.17.12/13). Post-process the cache-fetched package
  # rather than overrideAttrs: a source rebuild can't even succeed on WSL2
  # (opencode's build script smoke-tests the fresh binary, which segfaults
  # before any fixup runs) and would forfeit the binary cache. bin/opencode
  # is a compiled C wrapper with the original out-path baked in; reusing the
  # original derivation name makes both store paths the same length, so the
  # self-reference can be retargeted with an in-place equal-length rewrite.
  # Drop the overlay once upstream is fixed.
  nixpkgs.overlays = [
    (final: prev: {
      opencode =
        final.runCommand prev.opencode.name
          {
            nativeBuildInputs = [ final.patchelf ];
            inherit (prev.opencode) meta;
          }
          ''
            cp -a ${prev.opencode} $out
            chmod -R u+w $out
            find $out -type f -exec sed -i "s|${prev.opencode}|$out|g" {} +
            patchelf --set-interpreter \
              "$(patchelf --print-interpreter "$out/bin/.opencode-wrapped")" \
              "$out/bin/.opencode-wrapped"
          '';
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
    rebuild = "sudo ${flakePath}/scripts/rebuild-local.sh nixos";
    rebuild-headless = "sudo ${flakePath}/scripts/rebuild-local.sh nixos-headless";
  };
}
