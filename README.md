# nix-config

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
├── .github/
│   ├── scripts/
│   │   └── update-synergy3.sh      # discovers latest release, fetches guest tokens, hashes Linux + macOS installers
│   └── workflows/
│       ├── update-flake-lock.yml   # weekly lock-update PR, validated by evaluating all four outputs
│       ├── check-config.yml        # context integration tests and all four output evaluations on PRs
│       └── update-synergy3.yml     # weekly pinned version/hash PR, validates both installers + all outputs
├── flake.nix                       # inputs + nixosConfigurations.{nixos,nixos-headless,nixos-default} + darwinConfigurations.macbook
├── flake.lock                      # pinned input revisions — the reproducibility guarantee
├── lib/
│   └── mk-host.nix                 # shared factory for public outputs and private context compositions
├── contexts/
│   └── template/                   # portable context flake with Home Manager and OS modules
├── tests/
│   ├── contexts-eval.nix           # cross-platform context composition checks
│   ├── workspace-eval.nix          # actual Git profile definitions for integration tests
│   ├── check.sh                    # context tests and all four output evaluations
│   ├── config_test.py             # CLI lifecycle tests and opt-in Nix integration
│   ├── environments_test.py       # generated-file ownership and direnv inheritance
│   └── workspace_test.py          # folder-scoped Git identities and linked worktrees
├── pkgs/
│   ├── overlay.nix                 # packages not in nixpkgs (imported by modules/common.nix + modules/darwin.nix)
│   ├── prime-agent/                # pinned native Rust releases for Linux and Apple Silicon
│   └── synergy3/                   # pinned Flatpak/DMG installers with hash-verified guest-token fetching
├── modules/
│   ├── contexts.nix                # context metadata, user selection, and generation manifest
│   ├── common.nix                  # shared (NixOS): nix settings, overlays, packages, unfree, zsh, fonts
│   ├── desktop.nix                 # GNOME + Steam (shared by both NixOS hosts)
│   ├── synergy3.nix                # system Flatpak install/update (all NixOS hosts, including hosts without Home Manager users)
│   ├── synergy3-darwin.nix         # macOS: copies the pinned Synergy.app to /Applications (path is hardcoded upstream)
│   ├── wsl.nix                     # WSL-only: user, runtime directory, sudo, and network integration
│   ├── git-ignores.nix             # shared global git ignore list (data, used by common.nix + home/git.nix)
│   ├── darwin.nix                  # macOS system layer: nix settings, unfree, fonts, CLI tools, Homebrew (nix-darwin)
│   ├── primary-user.nix            # local.primaryUser option: macOS account name, overridable from ~/.config/nix/local.nix
│   ├── local-agents.nix             # typed host-local OpenCode agent inference overrides
│   ├── local-llm.nix               # optional host-local Ollama and OpenCode routing
│   ├── local-llm-nixos.nix         # NixOS Ollama service wiring
│   └── local-llm-darwin.nix        # nix-darwin launchd wiring
├── hosts/
│   ├── nixos-wsl.nix               # WSL host  = common + desktop + synergy3 + wsl (nixos / nixos-headless outputs)
│   ├── nixos-default.nix           # non-WSL host = common + desktop + synergy3 + nixos-default-hardware
│   ├── nixos-default-hardware.nix  # PLACEHOLDER — replace via nixos-generate-config
│   └── macbook.nix                 # macOS host = darwin.nix + home-manager module (darwinConfigurations.macbook)
├── home/                           # per-user home-manager config
│   ├── config.nix                  # config command with Python, Git, and Nix runtime tools
│   ├── contexts.nix                # ownership-checked context environments from locked compositions
│   ├── workspace.nix               # folder-scoped Git identities, with nested profiles
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
├── prime/
│   └── settings.json               # global Prime Agent settings (~/.prime/agent/settings.json links here)
├── opencode/
│   ├── opencode.jsonc              # global OpenCode settings
│   ├── local-profile.nix            # startup evaluator for ~/.config/nix/local.nix
│   ├── tui.json                     # global OpenCode UI theme
│   ├── agents/                      # OpenCode auto-agent definitions
│   ├── commands/                    # /auto, /research, /plan, and related commands
│   ├── skills/                      # OpenCode auto-agent skills
│   ├── plugins/                     # OpenCode runtime plugins
│   ├── scripts/                     # PR watcher and history finalizer helpers
│   ├── tests/                       # auto-agent contract tests
│   └── README.md                    # auto-agent usage and maintenance guide
├── scripts/
│   ├── config.py                   # context registration, locked compositions, status, check, and rebuild
│   ├── context_envrcs.py            # generated .envrc ownership, replacement, and removal
│   └── rebuild-local.sh            # bootstrap wrapper for the config command
└── agents/                         # tool-agnostic agent config (~/.agents links here)
    ├── mcp.json                    # shared MCP servers (Claude picks up via --mcp-config alias)
    ├── .skill-lock.json            # source and hash of upstream skills (written by gh skill)
    └── skills/
        ├── code-search/SKILL.md    # skill: semantic and literal code search
        ├── new-project/SKILL.md    # skill: bootstrap a new project (flake, direnv, AGENTS.md, docs)
        ├── handoff/SKILL.md        # skill: compact the conversation into a handoff doc for another agent
        ├── explain-diff/SKILL.md   # skill: rich HTML explanation of a diff, branch, or PR
        ├── gh-stack/                # skill: stacked PRs with gh-stack (vendored from github/gh-stack)
        │   ├── SKILL.md
        │   └── references/          # command reference, stack design, troubleshooting
        ├── please-continue/SKILL.md # skill: resume interrupted work after sleep or a stalled session
        ├── ste-writing/             # skill: write prose in Simplified Technical English to remove AI slop
        │   ├── SKILL.md
        │   └── scripts/ste-lint.py  # mechanical STE checker (run via nix shell nixpkgs#python3)
        └── tickets/                 # skill: GitHub Projects V2 Kanban ticket workflow
            ├── SKILL.md
            ├── contracts/kanban-v1.json
            ├── fixtures/             # sanitized contract-verification fixtures
            ├── scripts/project-contract.sh
            └── tests/project-contract-test.sh
```

### OpenCode Models And Profiles

OpenCode agent inference uses the repository's `github-copilot` profile by
default. To select or override a profile, or to choose models for OpenCode's
built-in Build and Plan agents, create `~/.config/nix/local.nix`. During a
rebuild the file is copied into the Nix store, and it is also read by OpenCode
at startup, so it must not contain secrets. For example:

```nix
{ pkgs, ... }:
{
  local.llm = {
    enable = true;
    package = pkgs.ollama;
    model = "qwen3-coder:30b";
    # Keep the ~21 GB model GPU-resident to avoid cold-load latency after idle.
    keepAlive = "24h";
  };

  local.opencode.build = {
    model = "ollama/<model>";
    reasoningEffort = "high";
  };
  local.opencode.plan = {
    model = "github-copilot/<model>";
    reasoningEffort = "xhigh";
  };
  local.opencode.agents = {
    provider = "local-profile";
    providers.local-profile = {
      auto-researcher = {
        model = "ollama/<model>";
        reasoningEffort = "high";
      };
      auto-reviewer = {
        model = "github-copilot/gpt-5.6-sol";
        reasoningEffort = "high";
      };
    };
  };
}
```

`local.opencode.build` and `.plan` configure OpenCode's built-in Build and Plan
agents. Each accepts `model` and `reasoningEffort`. They are separate from
custom-agent profiles and do not override the top-level `model` in
`opencode.jsonc`; static variants in that file remain active. Do not put
`build` or `plan` under `local.opencode.agents.providers`.

Switch profiles by changing `provider`; host-local profile entries merge onto
the repository profile of the same name. Here, `provider` is a profile key,
not an OpenCode provider declaration. Custom profiles may configure repository
agents such as `auto-researcher` and `auto-reviewer` with the inference fields
`model`, `reasoningEffort`, `variant`, `temperature`, and `top_p`. Set one to
`null` to remove the repository default. Prompts, descriptions, modes, colors,
and permissions remain repository-owned. OpenCode evaluates these profile
settings from `local.nix` when it starts, so changing them requires only an
OpenCode restart. The rebuild helper still supplies the file as the
directory-shaped `local-config` input for system and Ollama service settings.
Then run `ollama pull qwen3-coder:30b` once; rebuilds never download models.
Check the service with `ollama ps` and `curl http://127.0.0.1:11434/v1/models`.

Ollama unloads idle models after five minutes by default. A large model can take
noticeable time to load again, so set `local.llm.keepAlive` when low first-token
latency matters. This keeps the model's memory allocated until the interval
expires. Unload it manually without deleting the download with:

```sh
ollama stop qwen3-coder:30b
```

Confirm it is no longer resident with `ollama ps`.

The built-in Plan agent is distinct from this repository's `/plan` command:
`/plan` invokes the custom `auto-planner`, which writes the TDD plan and asks
for approval. The `auto-planner` profile is therefore configured under
`local.opencode.agents.providers`, while the built-in Plan settings use
`local.opencode.plan`.

OpenCode evaluates `local.nix` at startup. Changing its OpenCode profile
settings, or directly editing the repository's `opencode/opencode.jsonc` or
routing plugin, requires only an OpenCode restart. Changes to Ollama service
settings still require a rebuild. Any configured `ollama/...` agent model
requires Ollama to be enabled and to match `local.llm.model`; downloaded model
data remains until explicitly removed with `ollama rm <model>` (or by removing
Ollama's data directory).

(The WSL host has no `hardware-configuration.nix` — `nixos-wsl` provides the
root filesystem. Generate one only for a real non-WSL machine.)

### How WSL is kept optional

The `nixos-wsl` flake module and `modules/wsl.nix` are only referenced by the
`nixos` host. The `nixos-default` host imports neither, so it builds on non-WSL
hardware without any WSL assumptions.

## Contexts across hosts

The `config` command combines this shared base, the selected host, registered
context repositories, and `~/.config/nix/local.nix`. A context is a separate
repository, such as `~/Work/config`. Register it only on machines that need it.

| Layer | Owns |
| --- | --- |
| This repository | Shared tools, shell, editors, and agent configuration |
| `hosts/` | Hardware, platform, user accounts, graphical mode, and state versions |
| A context repository | Work or client tools, Git profiles, and platform additions |
| `~/.config/nix/local.nix` | Machine-local settings such as Ollama and model routing |
| A project repository | Its dependencies and project-specific agent instructions |

Contexts support both `x86_64-linux` and `aarch64-darwin`. They export
`homeManagerModules.default`, optional `nixosModules.default` and
`darwinModules.default`, and optional `devShells.<system>.default`.

**Module packages and settings apply across the machine.** Git profiles and
dev shells apply within the context directory. Contexts do not isolate processes.
Nix merges module options, rather than giving the last context automatic priority.
Lists usually combine. Conflicting scalar settings require an explicit override.

### Commands

| Command | Action |
| --- | --- |
| `config` | Show the host, base revision, local settings status, and context status |
| `config contexts` | Show registered contexts and applied revisions |
| `config context new ~/Work/config` | Scaffold, stage, and register a separate context repository |
| `config contexts add ~/Work/config` | Register an existing context repository |
| `config contexts remove ~/Work/config` | Unregister a context for the next rebuild |
| `config check` | Build the composition without activation |
| `config check --eval` | Evaluate the composition without building |
| `config rebuild` | Build as the user, then activate through the platform rebuild tool |
| `config rebuild --target nixos-headless` | Select a different host output explicitly |
| `config help` | Show command help |

The active generation supplies the default target. WSL graphical and headless
outputs share the same registry. `rebuild` selects graphical WSL and
`rebuild-headless` selects headless WSL. On macOS, `rebuild` selects `macbook`.
Use `--target` to override the target for a check or rebuild.

Registrations live in `~/.config/nix/contexts.json`. Missing registered
repositories stop the build. Restore the repository or explicitly unregister it.
This prevents an absent context from silently removing its Homebrew casks.
Context paths must be inside a directory under your home. Spaces are supported.

### Set up a work context

First install the command with the bootstrap helper from this checkout:

```sh
./scripts/rebuild-local.sh nixos          # graphical WSL
# ./scripts/rebuild-local.sh nixos-headless
# ./scripts/rebuild-local.sh macbook     # existing nix-darwin installation
```

Open a new shell after activation. Then create the work repository:

```sh
config context new ~/Work/config
```

Edit `~/Work/config/home.nix` to declare your work identity:

```nix
{ pkgs, ... }:
{
  workspace.gitProfiles.work = {
    directory = "Work";
    name = "Your Name";
    email = "your-work-account@users.noreply.github.com";
  };

  # Packages here are available everywhere on this machine.
  home.packages = with pkgs; [ ];
}
```

Use your work account's actual approved address. The base noreply identity stays
active outside `~/Work`. Nested profiles override parent profiles. Git selects
profiles by its Git-directory path. A linked worktree retains its source
repository's profile, even when the worktree sits outside that directory.

Add folder-only tools to the `packages` list in `~/Work/config/flake.nix`.
For a simple test, add `hello`. Leave `nixos.nix` and `darwin.nix` empty until
you need system settings. macOS-only casks belong in `darwin.nix`.

```sh
git -C ~/Work/config add flake.nix home.nix nixos.nix darwin.nix
config check --eval
config check
config rebuild
config contexts
```

After activation, test the identity and folder tool:

```sh
git -C ~/Work/config config --show-origin user.email
git -C ~/oss/nix-config config --show-origin user.email
direnv exec ~/Work hello
```

The first identity should be your work address. The second should remain the
base noreply address. The last command should print Hello, world! from the work
shell. Home Manager creates and approves `~/Work/.envrc` during activation.
Checks and activation refuse to replace an existing user-owned `.envrc`.

For a project with its own `.envrc`, load the parent context before its tools:

```sh
source_up_if_exists
use flake
```

Run `direnv allow` in that project after editing its `.envrc`.
The new-project skill generates this inheritance by default.

Commit the context files in the work repository. Then rebuild once more to record
the clean commit as applied. Create a private remote for that repository:

```sh
git -C ~/Work/config commit -m "Configure work context"
gh repo create work-config --private --source="$HOME/Work/config" --remote=origin
git -C ~/Work/config push -u origin main
config rebuild
```

On another configured machine, clone and register that same repository:

```sh
git clone git@github.com:YOUR-ACCOUNT/work-config.git ~/Work/config
config contexts add ~/Work/config
config check
config rebuild
```

Each host selects its matching platform modules and shell. Use the same base
lock and work-repository commit when you want matching dependency versions.
The `nixos-default` template needs a real user, a Home Manager entry, and
`contexts.user` before it can apply a Home Manager context.

### Snapshots, credentials, and removal

Each check or rebuild snapshots the tracked repository contents. New files must
be staged. Modified tracked files are supported and marked as dirty. A separate
repository commit is required to reproduce those changes on another machine.

Snapshots live in `~/.local/state/nix-config/builds/`. Each snapshot retains an
immutable `flake/` composition, its lock, a manifest, and source GC roots.
Build results stay outside `flake/`. Context shells load that exact composition,
so later checkout edits do not change an applied shell. A rebuild applies them.
The running generation records provenance in `/etc/nix-config/manifest.json`.
Keep snapshots used by current or rollback generations. Retired snapshots can be
removed to release their GC roots.

Private repositories keep work configuration out of this public repository.
Their sources and generated configuration still enter the Nix store.
Keep credentials in external files or runtime credential providers.
Agent instructions remain live-linked. OpenCode model overrides still use
machine-local `local.nix`, which OpenCode evaluates at startup.

To remove a context from a machine:

```sh
config contexts remove ~/Work/config
config check
config rebuild
```

This removes its declarations and unchanged generated `.envrc` files. It preserves
the context repository and user-modified environment files.

### Verify context changes

Run the Linux verification suite before merging context infrastructure changes:

```sh
bash tests/check.sh
```

It checks registration, local overrides, source snapshots, real Nix/direnv shells,
environment ownership and restoration, Git profiles, and linked worktrees.
It also evaluates all four outputs and portable context fixtures.
Activation still needs a check on each target platform.

## Applications

The rule: **any app nixpkgs can build is managed by nix**, per platform; only
the GUI apps nixpkgs can't build on macOS are installed as Homebrew casks
through nix-darwin (`modules/darwin.nix`). Steam and Mullvad are system-level
on NixOS (a `programs.*` / `services.*` module rather than home-manager).

| App | Linux | macOS | How it's managed |
| --- | --- | --- | --- |
| Spotify | ✅ | ✅ | nix, global — `home/default.nix` |
| Obsidian | ✅ | ✅ | nix, global — `home/default.nix` |
| Claude Desktop | — | ✅ | Homebrew cask, upgraded during Mac rebuilds — `modules/darwin.nix` |
| doctl | ✅ | ✅ | nix, global — `home/default.nix` |
| Pi coding agent | ✅ `pi-coding-agent` | ✅ `pi-coding-agent` | nix, global — `home/default.nix` |
| Signal | ✅ `signal-desktop` | ✅ `signal-desktop` | nix, global — `home/default.nix` |
| Synergy 3 | ✅ Flatpak bundle | ✅ Apple Silicon DMG | pinned custom package; NixOS activation (`modules/synergy3.nix`) / darwin activation (`modules/synergy3-darwin.nix`) |
| VLC | ✅ `vlc` | ✅ `vlc-bin` | nix, per-platform entrypoint |
| WhatsApp | ✅ `karere` (GTK4) | ✅ `whatsapp-for-mac` | nix, per-platform entrypoint |
| Firefox | ✅ `firefox` | ✅ `firefox-bin` | nix, per-platform entrypoint |
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

The Mac rebuild also upgrades Claude Desktop through a separate Homebrew Bundle
pass. It compares the installed app's version and preserves newer self-updated
versions.

Synergy 3's release and per-platform installer hashes are pinned in
`pkgs/synergy3/pinned.nix`. The weekly
`.github/workflows/update-synergy3.yml` workflow obtains fresh guest download
tokens, hashes the Linux Flatpak bundle and Apple Silicon DMG, validates both
installers, evaluates all four outputs, and opens a review PR. After merging,
the next rebuild updates the installed app. On NixOS, the system Flatpak module
installs the bundle and its runtime and exposes its desktop entry; on macOS,
darwin activation copies `Synergy.app` to `/Applications/`. Synergy hardcodes
that path for its background service, so a Home Manager or Nix Apps link won't
work; the copy is only replaced when the pinned build changes, and Synergy needs
a relaunch afterwards to re-register its service.
macOS will still ask for the user's Accessibility permission after the first
launch; approve Synergy in System Settings → Privacy & Security → Accessibility.

The NixOS-WSL build installs Synergy inside the Linux guest. To control the
Windows desktop itself, install Synergy on Windows as well: the WSL app cannot
inject input into its Windows host.

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
config rebuild --target nixos
```

Headless (no desktop; GUI apps like Ghostty still work via WSLg):

```sh
config rebuild --target nixos-headless
```

Switch between them on demand by rebuilding with the other attribute — both are
the same host, differing only in `local.graphical.enable`.

### Aliases

Home Manager defines shell aliases (in `home/config.nix`) so you do not type the
full flake path:

| Alias              | Runs                                              |
| ------------------ | ------------------------------------------------- |
| `rebuild`          | `config rebuild --target nixos` (graphical) |
| `rebuild-headless` | `config rebuild --target nixos-headless`    |

Both aliases are present in either mode, so `rebuild` will take you back to
graphical while headless (and vice versa).

**First-time bootstrap:** use the helper before the command and aliases exist:

```sh
./scripts/rebuild-local.sh nixos
```

After that, open a new shell and `rebuild` / `rebuild-headless` are available.

## macOS (nix-darwin)

The `macbook` output is a full nix-darwin system: home-manager runs as a
darwin module (like the NixOS hosts) and **nix-homebrew** manages Homebrew for
the handful of GUI apps nixpkgs can't build on darwin (see
[Applications](#applications)). Per-machine facts live in `hosts/macbook.nix`
(the primary user, `hostPlatform`, and `stateVersion`); set
`local.primaryUser` in `~/.config/nix/local.nix` for a different account.
Shared darwin system config
(nix settings, unfree allowlist, fonts, base CLI tools, Homebrew) lives in
`modules/darwin.nix`. `home/darwin.nix` is the home entrypoint.

1. Install Nix with the official multi-user installer:

   ```sh
   sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon
   ```

   Before the first nix-darwin run, enable flakes in `/etc/nix/nix.conf`:

   ```sh
   printf '%s\n' 'experimental-features = nix-command flakes' | sudo tee -a /etc/nix/nix.conf
   ```

   `modules/darwin.nix` keeps this setting managed after the initial bootstrap.
2. Clone this repo to `~/oss/nix-config` — the live symlinks and the
   `rebuild` alias assume that path.
3. First run (nix-darwin isn't installed yet) — this also installs Homebrew
   via nix-homebrew:

   ```sh
   sudo nix run nix-darwin -- switch --flake "path:$HOME/oss/nix-config#macbook"
   ```

   Pre-existing dotfiles (macOS ships a default `.zshrc`) are moved aside via
   `backupFileExtension = "hm-bak"` (`hosts/macbook.nix`).
4. Thereafter use `config rebuild` or `rebuild` (aliased in `home/config.nix`).

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

`home/emacs.nix` installs the latest Emacs from nixpkgs and puts Doom's CLI
(`~/.config/emacs/bin`) on PATH. The private Doom config
(`init.el` / `config.el` / `packages.el`) lives in `doom/` in this repo, and
home-manager symlinks `~/.config/doom` to it (`mkOutOfStoreSymlink` in
`home/default.nix`), so those files are the single source of truth.

Doom itself manages its own packages, so the framework is bootstrapped
**once**, imperatively, after the first rebuild — do this *before* ever
launching Emacs:

```sh
git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.config/emacs
doom install        # ~/.config/emacs/bin is already on PATH (new shell)
```

Emacs prefers `~/.emacs.d` over the XDG `~/.config/emacs` when both exist, so
launching Emacs even once before this clone creates an empty `~/.emacs.d`
that silently shadows Doom on every subsequent launch (you'll get the stock
Emacs splash screen instead of the Doom dashboard). If that happens, `rmdir
~/.emacs.d` (it only succeeds if the directory is empty) and relaunch.

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

Global opencode settings and TUI preferences are tracked in
`opencode/opencode.jsonc` and `opencode/tui.json`; home-manager symlinks them
to `~/.config/opencode/` (`mkOutOfStoreSymlink` in `home/default.nix`), the
same pattern as Claude Code's settings.json. Edit settings in the repo files —
the rest of `~/.config/opencode` (node_modules, caches, etc.) is left as
mutable state.

OpenCode's auto-agent is maintained in this repository under `opencode/`.
Home-manager exposes its agents, commands, and skills in the global OpenCode
configuration, and exposes its PR watcher and history finalizer in
`~/.local/bin`. Improve the relevant file under `opencode/` and run the harness
tests before evaluating the NixOS outputs.

## Pi

[Pi](https://pi.dev/) comes from the pinned nixpkgs package `pi-coding-agent`
in `home/default.nix` on Linux and macOS. After a rebuild, run `pi` in a
project directory and use `/login` to connect a provider.

Home Manager links `~/.pi/agent/AGENTS.md` and `~/.pi/agent/skills` to the
shared instructions and skills under `~/.agents`. Credentials, sessions,
and user settings stay in the local, mutable `~/.pi/agent` directory.
The nixpkgs package disables Pi telemetry and version checks by default.
The flake lock controls package updates.

## Prime Agent

[Prime Agent](https://github.com/PrimeIntellect-ai/prime-agent) is not in
nixpkgs. `pkgs/prime-agent/` packages its pinned native Rust releases for
Linux and Apple Silicon. To update it, change the version and both archive
hashes from upstream's `releases/vX.Y.Z/SHA256SUMS`. The shared overlay in
`pkgs/overlay.nix` exposes the package on both platforms.

The package keeps the Python runtime assets beside the executable. Its
package-local uv adapter uses Nix Python to create the kernel environment
on first use. This avoids generic Python downloads that cannot run on NixOS.
The Rust daemon uses a separate socket from older TypeScript installations.

Global settings are tracked in `prime/settings.json`; home-manager symlinks it
to `~/.prime/agent/settings.json` (`mkOutOfStoreSymlink` in
`home/default.nix`), the same pattern as Claude Code's and OpenCode's
settings. Credentials (`/login`) stay in the untracked, mutable
`~/.prime/agent/auth.json`. Unlike the other two tools, Prime Agent needs no
skills alias — it reads `~/.agents/skills/` natively.

## Agent skills

Shared agent skills are tool-agnostic and never duplicated per tool. The source of
truth is `agents/skills/<name>/SKILL.md` in this repo, exposed at `~/.agents`
(the universal agent-config directory). Claude Code and Pi read them through
aliases in `home/default.nix`: `~/.claude/skills` and `~/.pi/agent/skills`
both point to `~/.agents/skills`.
OpenCode's `tickets` entry similarly aliases `~/.agents/skills/tickets` into
its global skill directory. The skill manages repository GitHub issues as items
in an approved built-in Kanban project; it does not maintain a local
`.projects/` board. Prime Agent reads `~/.agents/skills/` directly, no alias
needed. Any other agent CLI gets its own alias into `~/.agents` the same way.
Because the links point at the checkout, adding or editing a skill takes effect
without a rebuild. The tickets skill resolves its verifier and Kanban contract
from that global skill directory, so it can operate on repositories outside
this checkout.

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

Flake input updates arrive as a weekly PR: `.github/workflows/update-flake-lock.yml` runs
`nix flake update` every Monday, tests contexts and evaluates all four outputs
against the new lock, and opens/refreshes a PR on the `flake-updates` branch only if they
pass. Review, merge, then `rebuild` — nothing lands on the machine
unattended. Security fixes in pinned inputs only reach the system through
this loop, so don't let the PRs pile up. The workflow needs the repo setting
"Allow GitHub Actions to create and approve pull requests"
(Settings → Actions → General).

Synergy 3 version and installer updates are proposed separately by
`.github/workflows/update-synergy3.yml` on the same weekly cadence. Review and
merge that PR before rebuilding to install the new pinned release.

Manual update, when you don't want to wait for Monday:

```sh
nix flake update                 # all inputs
nix flake update nixpkgs         # just one
config rebuild
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
sudo nixos-rebuild switch --flake github:<you>/nix-config#nixos
```
