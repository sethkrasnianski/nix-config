# nixos-config

Flake-based NixOS configuration with three outputs:

- **`nixos`** — this NixOS-WSL machine, graphical (GNOME).
- **`nixos-headless`** — the same WSL machine, no desktop.
- **`nixos-default`** — a non-WSL template (no WSL code), for real hardware.

## Layout

```
.
├── .github/workflows/
│   └── update-flake-lock.yml       # weekly lock-update PR, validated by evaluating all three outputs
├── flake.nix                       # inputs + nixosConfigurations.{nixos,nixos-headless,nixos-default}
├── flake.lock                      # pinned input revisions — the reproducibility guarantee
├── modules/
│   ├── common.nix                  # shared: nix settings, packages, unfree, zsh, fonts
│   ├── desktop.nix                 # GNOME (shared by both hosts)
│   └── wsl.nix                     # WSL-only: wsl.enable, opencode overlay, rebuild aliases (imported by the nixos host)
├── hosts/
│   ├── nixos-wsl.nix               # WSL host  = common + desktop + wsl (nixos / nixos-headless outputs)
│   ├── nixos-default.nix           # non-WSL host = common + desktop + nixos-default-hardware
│   └── nixos-default-hardware.nix  # PLACEHOLDER — replace via nixos-generate-config
├── home/                           # per-user home-manager config, wired in by hosts/*.nix
│   ├── default.nix                 # imports, user packages, and managed config symlinks
│   ├── git.nix / ssh.nix / shell.nix / direnv.nix
│   ├── neovim.nix / emacs.nix      # editor config
│   └── ghostty.nix                 # Ghostty terminal (WSLg Wayland GUI app)
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
        └── handoff/SKILL.md        # skill: compact the conversation into a handoff doc for another agent
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
any other agent CLI gets its own alias into `~/.agents` the same way. Because
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
