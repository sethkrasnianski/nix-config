# nixos-config

Flake-based NixOS configuration with two hosts:

- **`nixos`** — this NixOS-WSL machine.
- **`nixos-default`** — a non-WSL template (no WSL code), for real hardware.

## Layout

```
.
├── flake.nix                       # inputs + nixosConfigurations.{nixos,nixos-default}
├── flake.lock                      # pinned input revisions — the reproducibility guarantee
├── modules/
│   ├── common.nix                  # shared: nix settings, packages, unfree, zsh, + neovim
│   ├── desktop.nix                 # GNOME (shared by both hosts)
│   ├── wsl.nix                     # WSL-only: wsl.enable, DISPLAY hack (imported by the nixos host)
│   └── neovim.nix                  # editor config (enabled via common.nix)
├── hosts/
│   ├── nixos-wsl.nix               # WSL host  = common + desktop + wsl
│   ├── nixos-default.nix           # non-WSL host = common + desktop + nixos-default-hardware
│   └── nixos-default-hardware.nix  # PLACEHOLDER — replace via nixos-generate-config
```

(The WSL host has no `hardware-configuration.nix` — `nixos-wsl` provides the
root filesystem. Generate one only for a real non-WSL machine.)

### How WSL is kept optional

The `nixos-wsl` flake module and `modules/wsl.nix` are only referenced by the
`nixos` host. The `nixos-default` host imports neither, so it builds on non-WSL
hardware without any WSL assumptions.

## Rebuild (this WSL machine)

Graphical (GNOME desktop) — the default:

```sh
sudo nixos-rebuild switch --flake ~/personal/nixos-config#nixos
```

Headless (no desktop; GUI apps like Ghostty still work via WSLg):

```sh
sudo nixos-rebuild switch --flake ~/personal/nixos-config#nixos-headless
```

Switch between them on demand by rebuilding with the other attribute — both are
the same host, differing only in `local.graphical.enable`.

### Aliases

The WSL host defines shell aliases (in `modules/wsl.nix`) so you don't type the
full flake path:

| Alias              | Runs                                              |
| ------------------ | ------------------------------------------------- |
| `rebuild`          | `nixos-rebuild switch --flake …#nixos` (graphical) |
| `rebuild-headless` | `nixos-rebuild switch --flake …#nixos-headless`    |

Both aliases are present in either mode, so `rebuild` will take you back to
graphical while headless (and vice versa).

**First-time bootstrap:** the aliases don't exist on a system that hasn't been
built from this config yet (including right now). Run the full command once to
install them:

```sh
sudo nixos-rebuild switch --flake ~/personal/nixos-config#nixos
```

After that, open a new shell and `rebuild` / `rebuild-headless` are available.

## Use on a non-WSL machine

1. Boot the target machine and run `sudo nixos-generate-config`, then replace
   the contents of `hosts/nixos-default-hardware.nix` with the generated
   `/etc/nixos/hardware-configuration.nix`.
2. Adjust the bootloader in `hosts/nixos-default.nix` for that hardware.
3. Set `system.stateVersion` in `hosts/nixos-default.nix` to the release current at
   install time.
4. Build: `sudo nixos-rebuild switch --flake .#nixos-default`

## Desktop

`modules/desktop.nix` provides GNOME (with GDM), gated behind the
`local.graphical.enable` option (default `true`). Set it to `false` for a
headless host. The WSL box exposes both as flake outputs (`#nixos` /
`#nixos-headless`); `#nixos-default` is graphical by default.

### Running GNOME on the WSL host

GDM can't present a login screen under WSL (no GPU/seat/monitor), so on the
graphical build GNOME won't appear on its own. To run GNOME Shell in a WSLg
window on the Windows desktop:

```sh
dbus-run-session -- gnome-shell --devkit --no-x11
```

`--no-x11` is required because WSLg mounts `/tmp/.X11-unix` read-only, so
GNOME's own Xwayland can't start — only Wayland-native apps run *inside* this
session (launch them with `WAYLAND_DISPLAY=wayland-1 <app>` from another
terminal). X11 apps still work directly on WSLg as usual.

## Update pinned inputs

```sh
nix flake update                 # all inputs
nix flake update nixpkgs         # just one
sudo nixos-rebuild switch --flake ~/personal/nixos-config#nixos
```

Commit `flake.lock` after updating.

## Secrets

This repo contains **no secrets** and is safe to publish (public or private).
Keep it that way: **never commit a plaintext secret.**

Things that are secrets and must not be inlined in these files:

- `users.users.<name>.hashedPassword` / `initialPassword`
- WiFi keys — `networking.wireless.networks.*.psk`
- API tokens and authtokens (e.g. an `ngrok` authtoken)
- Private SSH keys, age/GPG private keys, TLS certificates

When you need any of these, don't paste them in — use
[sops-nix](https://github.com/Mic92/sops-nix) or
[agenix](https://github.com/ryantm/agenix). Both keep secrets **encrypted**
inside the repo and decrypt them at build/activation time, so the repo stays
publishable.

> ⚠️ Making the repo private *after* a secret was committed does **not** undo the
> exposure — it remains in git history. If that happens, scrub the history
> (e.g. `git filter-repo`) **and rotate the leaked secret**, since you must
> assume it's compromised.

## Reproduce from a remote

```sh
sudo nixos-rebuild switch --flake github:<you>/nixos-config#nixos
```
