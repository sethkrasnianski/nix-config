# Applications

[README](../README.md) · [Repository layout](layout.md)

Nix manages applications that nixpkgs can build on each platform. Homebrew casks
cover the remaining macOS GUI applications through nix-darwin (`modules/darwin.nix`).
Steam and Mullvad use NixOS system modules instead of Home Manager.

## Application matrix

This selected catalog describes the base configuration for `x86_64-linux` and
`aarch64-darwin`. Context repositories and machine-local settings can add or change
applications. A check mark means the configuration installs the application.
Xcode needs a separate installation.

Home Manager installs shared applications for the configured user on WSL and macOS.
The `nixos-default` template needs a Home Manager user before it includes those
applications. Headless WSL keeps Home Manager applications but disables Steam
with the desktop.

| App | Linux | macOS | Management |
| --- | --- | --- | --- |
| Spotify | ✅ | ✅ | Nix, shared per-user configuration — `home/default.nix` |
| Obsidian | ✅ | ✅ | Nix, shared per-user configuration — `home/default.nix` |
| Claude Desktop | — | ✅ | Homebrew cask, upgraded during Mac rebuilds — `modules/darwin.nix` |
| doctl | ✅ | ✅ | Nix, shared per-user configuration — `home/default.nix` |
| Pi coding agent | ✅ `pi-coding-agent` | ✅ `pi-coding-agent` | Nix, shared per-user configuration — `home/default.nix` |
| Signal | ✅ `signal-desktop` | ✅ `signal-desktop` | Nix, shared per-user configuration — `home/default.nix` |
| Synergy 3 | ✅ Flatpak bundle | ✅ Apple Silicon DMG | Pinned custom package — `modules/synergy3.nix` / `modules/synergy3-darwin.nix` |
| VLC | ✅ `vlc` | ✅ `vlc-bin` | Nix — `home/linux.nix` / `home/darwin.nix` |
| WhatsApp | ✅ `karere` (GTK4) | ✅ `whatsapp-for-mac` | Nix — `home/linux.nix` / `home/darwin.nix` |
| Firefox | ✅ `firefox` | ✅ `firefox-bin-unwrapped` | Nix — `home/linux.nix` / `home/darwin.nix` |
| UTM | — | ✅ `utm` | Nix — `home/darwin.nix` |
| Parsec | ✅ `parsec-bin` | ✅ | Linux: Nix (`home/linux.nix`). macOS: Homebrew cask |
| Steam | ✅ Graphical only | ✅ | Linux: `programs.steam` (`modules/desktop.nix`). macOS: Homebrew cask |
| Mullvad VPN | ✅ | ✅ | Linux: `services.mullvad-vpn` (`modules/common.nix`). macOS: Homebrew cask |
| GIMP (PhotoGIMP) | ✅ `gimp` | ✅ | Linux: Nix (`home/linux.nix`). macOS: Homebrew cask |
| Xcode | — | ⚙️ Manual | Nix installs the `xcodes` CLI — see [Xcode](../README.md#xcode) |

WhatsApp uses the third-party `karere` GTK4 client on Linux and the official
`whatsapp-for-mac` client on macOS. The Homebrew casks (`claude`, `parsec`, `steam`,
`mullvad-vpn`, and `gimp`) live in `modules/darwin.nix`.

The Mac rebuild upgrades Claude Desktop through a separate Homebrew Bundle pass.
It compares the installed version and preserves newer versions from its own updater.

## Synergy 3

`pkgs/synergy3/pinned.nix` pins the release and both platform installer hashes.
The weekly `.github/workflows/update-synergy3.yml` workflow gets fresh guest download
tokens and hashes the Linux Flatpak bundle and Apple Silicon DMG.

It validates both installers, evaluates all four outputs, and opens a review PR.
After that PR merges, the next rebuild updates the installed application.

On NixOS, the system Flatpak module installs the bundle and its runtime and exposes
its desktop entry. This includes hosts without Home Manager users. On macOS,
darwin activation copies `Synergy.app` to `/Applications/`.

Synergy requires that path for its background service. A Home Manager or Nix Apps
link does not work. Activation replaces the copy only when the pinned build changes.
Relaunch Synergy afterward to register its service again.

After the first launch, approve Synergy in System Settings → Privacy & Security →
Accessibility.

NixOS-WSL installs Synergy inside the Linux guest. To control the Windows desktop,
install Synergy on Windows too. The WSL application cannot inject input into its
Windows host.

## GIMP (PhotoGIMP)

[PhotoGIMP](https://github.com/Diolinux/PhotoGIMP) gives GIMP a Photoshop-like layout,
shortcuts, and tool configuration. It supplies configuration files rather than an
application package.

GIMP rewrites these files at runtime, including window layouts, shortcuts, and
session state. A read-only store symlink would prevent those changes.
Instead, `home/photogimp.nix` pins a PhotoGIMP release by tag and SHA-256 hash through
`fetchzip`. Activation copies its files into the GIMP user configuration directory:

- Linux: `~/.config/GIMP/3.2`
- macOS: `~/Library/Application Support/GIMP/3.2`

A version marker skips later copies of the same release, so in-app customizations
persist across rebuilds.

To update PhotoGIMP, change `version` in `home/photogimp.nix` and refresh both platform
hashes. A hash-mismatch error reports the expected hash during a rebuild.
A version change copies the files again and overwrites customizations to PhotoGIMP-managed files.
