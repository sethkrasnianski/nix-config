# nixos-config

Flake-based NixOS configuration with four outputs:

- **`nixos`** — this NixOS-WSL machine, graphical (GNOME).
- **`nixos-headless`** — the same WSL machine, no desktop.
- **`nixos-default`** — a non-WSL template (no WSL code), for real hardware.
- **`macbook`** — a Mac (aarch64-darwin) managed by nix-darwin, with
  home-manager as a darwin module and nix-homebrew for the few GUI apps
  nixpkgs can't build on darwin.

## Layout

```
.
├── .github/workflows/
│   └── update-flake-lock.yml       # weekly lock-update PR, validated by evaluating all four outputs
├── flake.nix                       # inputs + nixosConfigurations.{nixos,nixos-headless,nixos-default} + darwinConfigurations.macbook
├── flake.lock                      # pinned input revisions — the reproducibility guarantee
├── modules/
│   ├── common.nix                  # shared (NixOS): nix settings, packages, unfree, zsh, fonts
│   ├── desktop.nix                 # GNOME + Steam (shared by both NixOS hosts)
│   ├── wsl.nix                     # WSL-only: wsl.enable, opencode overlay, rebuild aliases (imported by the nixos host)
│   └── darwin.nix                  # macOS system layer: nix settings, unfree, fonts, CLI tools, Homebrew (nix-darwin)
├── hosts/
│   ├── nixos-wsl.nix               # WSL host  = common + desktop + wsl (nixos / nixos-headless outputs)
│   ├── nixos-default.nix           # non-WSL host = common + desktop + nixos-default-hardware
│   ├── nixos-default-hardware.nix  # PLACEHOLDER — replace via nixos-generate-config
│   └── macbook.nix                 # macOS host = darwin.nix + home-manager module (darwinConfigurations.macbook)
├── home/                           # per-user home-manager config
│   ├── default.nix                 # shared core: imports, user packages, managed config symlinks
│   ├── linux.nix                   # NixOS entrypoint (wired in by hosts/*.nix), carries home.stateVersion
│   ├── darwin.nix                  # macOS home entrypoint (nix-darwin module), carries home.stateVersion
│   ├── git.nix / ssh.nix / shell.nix / direnv.nix
│   ├── neovim.nix / emacs.nix      # editor config
│   ├── ghostty.nix                 # Ghostty terminal (WSLg Wayland on Linux, ghostty-bin on macOS)
│   └── photogimp.nix               # seeds GIMP's config dir from a pinned PhotoGIMP release
├── doom/                           # private Doom Emacs config (~/.config/doom links here)
├── claude/
│   └── settings.json               # global Claude Code settings (~/.claude/settings.json links here)
├── opencode/
│   ├── opencode.jsonc              # global OpenCode settings
│   ├── agents/                      # OpenCode auto-agent definitions
│   ├── commands/                    # /auto, /research, /plan, and related commands
│   ├── skills/                      # OpenCode auto-agent skills
│   ├── scripts/                     # PR watcher and history finalizer helpers
│   ├── tests/                       # auto-agent contract tests
│   └── README.md                    # auto-agent usage and maintenance guide
└── agents/                         # tool-agnostic agent config (~/.agents links here)
    ├── mcp.json                    # shared MCP servers (Claude picks up via --mcp-config alias)
    └── skills/
        ├── new-project/SKILL.md    # skill: bootstrap a new project (flake, direnv, AGENTS.md, docs)
        ├── handoff/SKILL.md        # skill: compact the conversation into a handoff doc for another agent
        └── tickets/SKILL.md        # skill: durable ticket board and per-ticket implementation plans
```

(The WSL host has no `hardware-configuration.nix` — `nixos-wsl` provides the
root filesystem. Generate one only for a real non-WSL machine.)

### How WSL is kept optional

The `nixos-wsl` flake module and `modules/wsl.nix` are only referenced by the
`nixos` host. The `nixos-default` host imports neither, so it builds on non-WSL
hardware without any WSL assumptions.

## Applications

The rule: **any app nixpkgs can build is managed by nix**, per platform; only
the GUI apps nixpkgs can't build on macOS are installed as Homebrew casks
through nix-darwin (`modules/darwin.nix`). Steam and Mullvad are system-level
on NixOS (a `programs.*` / `services.*` module rather than home-manager).

| App | Linux | macOS | How it's managed |
| --- | --- | --- | --- |
| Spotify | ✅ | ✅ | nix, global — `home/default.nix` |
| Obsidian | ✅ | ✅ | nix, global — `home/default.nix` |
| doctl | ✅ | ✅ | nix, global — `home/default.nix` |
| VLC | ✅ `vlc` | ✅ `vlc-bin` | nix, per-platform entrypoint |
| WhatsApp | ✅ `karere` (GTK4) | ✅ `whatsapp-for-mac` | nix, per-platform entrypoint |
| Firefox | ✅ `firefox` | ✅ `firefox-bin` | nix, per-platform entrypoint |
| Slack | — | ✅ `slack` | nix — `home/darwin.nix` |
| Teams | — | ✅ `teams` | nix — `home/darwin.nix` |
| UTM | — | ✅ `utm` | nix — `home/darwin.nix` |
| Parsec | ✅ `parsec-bin` | ✅ | Linux: nix; macOS: Homebrew cask |
| Steam | ✅ | ✅ | Linux: `programs.steam` (NixOS); macOS: Homebrew cask |
| Mullvad VPN | ✅ | ✅ | Linux: `services.mullvad-vpn` (NixOS); macOS: Homebrew cask |
| GIMP (PhotoGIMP) | ✅ `gimp` | ✅ | Linux: nix (`home/linux.nix`); macOS: Homebrew cask |
| Xcode | — | ⚙️ | not nix-installable — see [Xcode](#xcode) |

WhatsApp on Linux is the third-party `karere` GTK4 client (there is no official
Linux client); on macOS it's the official `whatsapp-for-mac`. The Homebrew
casks (`parsec`, `steam`, `mullvad-vpn`, `gimp`) are declared in
`modules/darwin.nix`.

### GIMP (PhotoGIMP)

GIMP is skinned with [PhotoGIMP](https://github.com/Diolinux/PhotoGIMP) — a
Photoshop-like layout, shortcuts, and tool config. PhotoGIMP isn't a package;
it's a set of files overlaid onto GIMP's user config dir. Because GIMP rewrites
most of those files at runtime (window layout, shortcuts, session state), they
can't be a read-only store symlink without fighting GIMP on every save.
Instead, `home/photogimp.nix` pins a PhotoGIMP release by tag + sha256 via
`fetchzip` and seeds `~/.config/GIMP/3.2` (`~/Library/Application
Support/GIMP/3.2` on macOS) from it **once** — a version marker file skips
re-seeding on later rebuilds, so your in-app customizations persist. To pull a
newer PhotoGIMP release, bump `version` in that file and refresh the
platform's hash (the rebuild's hash-mismatch error reports the correct one).

## Rebuild (this WSL machine)

Graphical (GNOME desktop) — the default:

```sh
sudo nixos-rebuild switch --flake ~/oss/nixos-config#nixos
```

Headless (no desktop; GUI apps like Ghostty still work via WSLg):

```sh
sudo nixos-rebuild switch --flake ~/oss/nixos-config#nixos-headless
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
sudo nixos-rebuild switch --flake ~/oss/nixos-config#nixos
```

After that, open a new shell and `rebuild` / `rebuild-headless` are available.

## macOS (nix-darwin)

The `macbook` output is a full nix-darwin system: home-manager runs as a
darwin module (like the NixOS hosts) and **nix-homebrew** manages Homebrew for
the handful of GUI apps nixpkgs can't build on darwin (see
[Applications](#applications)). Per-machine facts live in `hosts/macbook.nix`
(the username — **edit it there** if the account isn't `seth` — plus
`hostPlatform` and `stateVersion`); shared darwin system config
(nix settings, unfree allowlist, fonts, base CLI tools, Homebrew) lives in
`modules/darwin.nix`. `home/darwin.nix` is the home entrypoint.

1. Install Nix (e.g. the [Determinate installer](https://determinate.systems/nix-installer/),
   which enables flakes; with the upstream installer add
   `experimental-features = nix-command flakes` to `/etc/nix/nix.conf`).
2. Clone this repo to `~/oss/nixos-config` — the live symlinks and the
   `rebuild` alias assume that path.
3. First run (nix-darwin isn't installed yet) — this also installs Homebrew
   via nix-homebrew:

   ```sh
   sudo nix run nix-darwin -- switch --flake ~/oss/nixos-config#macbook
   ```

   Pre-existing dotfiles (macOS ships a default `.zshrc`) are moved aside via
   `backupFileExtension = "hm-bak"` (`hosts/macbook.nix`).
4. Thereafter just `rebuild` (aliased in `home/darwin.nix`), or the full
   `sudo darwin-rebuild switch --flake ~/oss/nixos-config#macbook`.

Apple's `/bin/zsh` stays the login shell and sources the home-manager rc
files — no `chsh` needed. Doom Emacs bootstraps the same way as on Linux
(see below); GUI apps from `home.packages` (Ghostty.app, Emacs.app) are
linked into `~/Applications/Home Manager Apps/` by home-manager's darwin
support.

The Dock ("taskbar") contents and order are managed declaratively in
`hosts/macbook.nix` (`system.defaults.dock`): the pinned apps, a Downloads
stack, and `show-recents = false`. It's reset to that on every rebuild, so
manual reordering won't stick. If a Dock icon shows as a "?", the app's `.app`
path in that file is wrong — check the real name under
`~/Applications/Home Manager Apps/`.

The output evaluates from the Linux machine too (pure eval, no darwin
builder needed) — this is the check to run before pushing macOS changes:

```sh
nix eval .#darwinConfigurations.macbook.system.drvPath --raw
```

### Xcode

Xcode itself can't be installed through nix (Apple licensing forbids
redistribution). What *is* packaged is **`xcodes`**, the CLI that downloads and
switches between full Xcode versions — installed on the Mac via
`home/darwin.nix`. Use it (a one-time Apple ID sign-in is required) rather than
committing Xcode to the config:

```sh
xcodes install --latest     # download + install the latest Xcode
xcodes installed            # list what's installed
xcodes select 16.0          # make a version active
```

Xcode is also available from the Mac App Store if you prefer.

The **Command Line Tools** (git, clang, `make`, headers) are separate from the
full IDE and install **automatically**: `modules/darwin.nix` runs
`xcode-select --install` on the first `darwin-rebuild switch` when they're
missing, so you just confirm Apple's prompt — no manual bootstrap step. Most
nix-driven work uses nix's own toolchain anyway; this covers tools that reach
for the system SDK. To reinstall them by hand later:

```sh
xcode-select --install
```

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

## Emacs (Doom)

`modules/emacs.nix` installs the latest Emacs from nixpkgs and puts Doom's CLI
(`~/.config/emacs/bin`) on PATH. The private Doom config
(`init.el` / `config.el` / `packages.el`) lives in `doom/` in this repo, and
home-manager symlinks `~/.config/doom` to it (`mkOutOfStoreSymlink` in
`home/default.nix`), so those files are the single source of truth.

Doom itself manages its own packages, so the framework is bootstrapped
**once**, imperatively, after the first rebuild:

```sh
git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.config/emacs
doom install        # ~/.config/emacs/bin is already on PATH (new shell)
```

Day-to-day: edit files in `doom/`; run `doom sync` after changing
`init.el` or `packages.el` (plain `config.el` changes don't need it).

## Claude Code

Global Claude Code settings are tracked in `claude/settings.json`; home-manager
symlinks `~/.claude/settings.json` to it (`mkOutOfStoreSymlink` in
`home/default.nix`). Only `settings.json` and `skills` are linked — the rest of
`~/.claude` is mutable state. Commit/PR attribution is disabled there. Edit
settings in the repo file: changes made through `/config` write through the
symlink, but if a rewrite replaces the link with a plain file, home-manager
restores it (discarding those changes) on the next rebuild.

## OpenCode

Global opencode settings are tracked in `opencode/opencode.jsonc`;
home-manager symlinks `~/.config/opencode/opencode.jsonc` to it
(`mkOutOfStoreSymlink` in `home/default.nix`), the same pattern as Claude
Code's settings.json. Edit settings in the repo file — the rest of
`~/.config/opencode` (node_modules, caches, etc.) is left as mutable state.

OpenCode's auto-agent is maintained in this repository under `opencode/`.
Home-manager exposes its agents, commands, and skills in the global OpenCode
configuration, and exposes its PR watcher and history finalizer in
`~/.local/bin`. Improve the relevant file under `opencode/` and run the harness
tests before evaluating the NixOS outputs.

## Agent skills

Shared agent skills are tool-agnostic and never duplicated per tool. The source of
truth is `agents/skills/<name>/SKILL.md` in this repo, exposed at `~/.agents`
(the universal agent-config directory). Claude Code reads them through an
alias — `~/.claude/skills` → `~/.agents/skills` — wired in `home/default.nix`;
OpenCode's `tickets` entry similarly aliases `~/.agents/skills/tickets` into
its global skill directory. Any other agent CLI gets its own alias into
`~/.agents` the same way. Because
the links point at the checkout, adding or editing a skill takes effect
without a rebuild.

MCP servers follow the same single-source-of-truth rule: they're defined in
`agents/mcp.json` (exposed at `~/.agents/mcp.json`). Claude Code has no global
`.mcp.json`, so instead of a symlink it's proxied by a `claude` shell function
that passes `--mcp-config ~/.agents/mcp.json` (`home/shell.nix`). The GitHub
server uses GitHub's hosted endpoint, which doesn't support OAuth dynamic
client registration, so it authenticates with a token in the `Authorization`
header. Rather than a separate PAT, the function looks up `gh auth token` at
invocation and sets `GITHUB_MCP_PAT` in that one command's environment only —
the config references `${GITHUB_MCP_PAT}`, so no token is ever stored in the
repo, and no other process inherits it.

## Update pinned inputs

Updates arrive as a weekly PR: `.github/workflows/update-flake-lock.yml` runs
`nix flake update` every Monday, evaluates all three outputs against the new
lock, and opens/refreshes a PR on the `flake-updates` branch only if they
pass. Review, merge, then `rebuild` — nothing lands on the machine
unattended. Security fixes in pinned inputs only reach the system through
this loop, so don't let the PRs pile up. The workflow needs the repo setting
"Allow GitHub Actions to create and approve pull requests"
(Settings → Actions → General).

Manual update, when you don't want to wait for Monday:

```sh
nix flake update                 # all inputs
nix flake update nixpkgs         # just one
sudo nixos-rebuild switch --flake ~/oss/nixos-config#nixos
```

Commit `flake.lock` after updating.

## ngrok

ngrok (`home/default.nix`) exposes a local port to the **public internet**.
Treat every tunnel as public — the random URL is not a secret, and scanners
find ngrok endpoints without needing to guess it.

- The authtoken is a secret: install it once with
  `ngrok config add-authtoken <token>` (stored in `~/.config/ngrok/ngrok.yml`,
  outside this repo). Never inline it in Nix files or shell rc (see Secrets
  below).
- Put auth on every tunnel to anything stateful or private:
  `ngrok http 3000 --oauth google --oauth-allow-email you@example.com`, or at
  minimum `--basic-auth 'user:long-random-password'`.
- Never tunnel a service that has default or no credentials of its own
  (database admin UIs, dev dashboards, anything bound to localhost on the
  assumption that localhost is private — a tunnel breaks that assumption).
- Tunnels live as long as the process: stop it when done rather than leaving
  it running unattended, and audit active endpoints at
  <https://dashboard.ngrok.com>.
- The local inspector (<http://localhost:4040>) records request/response
  bodies, including any credentials that pass through — another reason to
  stop the agent when finished.

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
