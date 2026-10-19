# nix-config

Flake-based NixOS config. Four outputs: `nixos` (WSL host, GNOME), `nixos-headless`
(same WSL host, no desktop), `nixos-default` (non-WSL template) — where home-manager
runs as a NixOS module, one rebuild applies system and user config together — and
`macbook` (a Mac, aarch64-darwin, managed by nix-darwin with home-manager as a
darwin module and nix-homebrew for the GUI apps nixpkgs can't build on darwin).

## Layout

- `flake.nix` — inputs: nixpkgs (nixos-unstable), nixos-wsl, home-manager, nix-darwin, nix-homebrew (all pinned by `flake.lock`)
- `lib/mk-host.nix`, `modules/contexts.nix`, `contexts/template/` — cross-platform host factory, context metadata, and the separate-repository template
- `scripts/config.py`, `scripts/context_envrcs.py` — the `config` CLI, locked context compositions, and ownership-checked folder environments
- `home/config.nix`, `home/contexts.nix`, `home/workspace.nix` — CLI packaging, context shell activation, and folder-scoped Git profiles
- `tests/check.sh` — CLI, Nix/direnv, Git integration tests, and all four output evaluations
- `.github/workflows/update-flake-lock.yml` — weekly `flake.lock` update PR; evaluates all four outputs before opening it
- `.github/workflows/update-synergy3.yml` — weekly Synergy 3 version/hash PR; validates both installers and evaluates all four outputs
- `hosts/` — per-host: hostname/`hostPlatform`, `system.stateVersion`, home-manager user wiring (`macbook.nix` is the nix-darwin host)
- `pkgs/` — packages not in nixpkgs: `prime-agent/` (pinned native Rust releases for Linux and Apple Silicon) and `synergy3/` (version-pinned Linux Flatpak and Apple Silicon DMG); `overlay.nix` is imported by both `modules/common.nix` and `modules/darwin.nix` so it's never duplicated
- `modules/` — system-level shared config: NixOS (`common.nix`, `desktop.nix`, `synergy3.nix`, `wsl.nix`) and darwin (`synergy3-darwin.nix`, `primary-user.nix` (the macOS `local.primaryUser` option, default `sethkrasnianski`, overridable from `~/.config/nix/local.nix`), `darwin.nix` — the macOS counterpart to `common.nix`: nix settings, overlays, unfree allowlist, fonts, base CLI tools, Homebrew; never imported by a NixOS host, and vice versa)
- `home/` — per-user home-manager config (git, ssh, shell, direnv, neovim, emacs);
  `default.nix` is the shared core, `linux.nix`/`darwin.nix` the per-platform
  entrypoints (NixOS hosts import `linux.nix`; `hosts/macbook.nix` imports
  `darwin.nix`). Both carry only `home.stateVersion`; username, unfree, and the
  system layer moved to `hosts/macbook.nix` + `modules/darwin.nix`. Two unfree
  allowlists — `modules/common.nix` (NixOS) and `modules/darwin.nix` (macOS) —
  must be kept in sync.
- `doom/`, `claude/settings.json`, `prime/settings.json`, `agents/`, `opencode/`
  — Doom Emacs, Claude Code, Prime Agent, tool-agnostic agent config, and
  OpenCode-specific agents/commands/skills, live-symlinked into `$HOME`
  (`home/default.nix`); edits apply without a rebuild

## Working in this repo

- Apply changes with `config rebuild` or `rebuild`; use `rebuild-headless` for
  headless WSL. These compose registered contexts and local.nix before activation.
  Bootstrap the command with `./scripts/rebuild-local.sh <target>`.
- Context repositories stay separate from this public repository. Register them
  with `config contexts add <path>`. New files must be staged before evaluation.
  A missing registered context stops a build. Use `config check` before rebuilding.
- Check without switching — all four outputs must evaluate:
  `nix eval .#nixosConfigurations.<name>.config.system.build.toplevel.drvPath --raw`
  and `nix eval .#darwinConfigurations.macbook.system.drvPath --raw`
  (pure eval; works from Linux, no darwin builder needed).
- `git add` new files before evaluating; flakes only see tracked files.
- Format Nix files with `nixfmt`.
- Keep the system/user split: base CLI tools, fonts, and login-shell plumbing in
  `modules/`; everything user-facing in `home/`.
- Small modules, one concern each, with a header comment explaining intent and
  non-obvious constraints.
- Never bump `system.stateVersion` or `home.stateVersion`.
- Commits: imperative subject plus a body explaining why; no AI-attribution lines.
- After editing `doom/init.el` or `doom/packages.el`, run `doom sync`
  (`config.el` changes don't need it).
- To bump Prime Agent's pinned version: update `version` and both platform
  hashes in `pkgs/prime-agent/default.nix`. Use the native release hashes from
  upstream's published `releases/vX.Y.Z/SHA256SUMS`. Build and check the Linux
  package, and verify the Apple Silicon archive checksum.
- Synergy 3's installer version and hashes live in `pkgs/synergy3/pinned.nix`;
  `.github/scripts/update-synergy3.sh` refreshes both platform artifacts using
  short-lived guest tokens, and the weekly workflow opens a reviewable PR.
- When you add, remove, move, or change the role of repository files, update
  `docs/layout.md` in the same commit. This includes configuration, packages,
  scripts, workflows, agent files, and documentation.
- When application declarations change, update `docs/applications.md` in the same
  commit. Check package names, platforms, installation methods, and enablement
  conditions against `home/`, `modules/`, `pkgs/`, and host wiring.
- When documentation moves, repair relative links and heading anchors in both
  directions. Check the links from `README.md` before committing.

## Agent skills

- Skills are tool-agnostic. The single source of truth is
  `agents/skills/<name>/SKILL.md`, exposed at `~/.agents` (the universal
  agent-config dir). Claude Code consumes them only through an alias —
  `~/.claude/skills` → `~/.agents/skills` (`home/default.nix`). Wire any new
  agent CLI the same way: give it an alias into `~/.agents`, never a copy, so
  no configuration is ever duplicated. Prime Agent and Codex are the
  exceptions so far — both glob `~/.agents/skills/` themselves, so they need
  no alias at all.
- A skill is a directory containing a `SKILL.md`: YAML frontmatter with `name`
  and `description` (the description is what triggers invocation — write it
  for matching), followed by the instructions.
- Adding or editing a skill needs no rebuild (the directory is live-symlinked);
  only creating the two links required the one initial `rebuild`.
- Third-party skills (now only `gh-stack`) are installed from upstream with
  `gh skill install <owner/repo> <skill> --scope user`. `gh skill` puts source
  metadata in each `SKILL.md` frontmatter and records the source and tree hash
  in `agents/.skill-lock.json`. Both are tool-written: do not edit them by
  hand. OpenCode reads `~/.config/opencode/skills` (= `opencode/skills/`), not
  `~/.agents`, so a skill installed for OpenCode as well has a second copy
  there. Update with `gh skill update <skill>` (`--dry-run` only reports).
  It finds and updates both copies, and it overwrites local edits, so change a
  vendored skill upstream, not here. Commit the two copies and the lock file
  together.
- OpenCode-specific auto-agent changes belong under `opencode/`. Improve the
  smallest relevant agent, command, or skill, preserve the approval/TDD/review
  boundaries, and run `opencode/tests/` before evaluating the flake outputs.

- Host-specific agent instructions live outside the repo in
  `~/.config/agents/AGENTS.local.md` (never committed). The shared
  `agents/AGENTS.md` tells every agent CLI to read it when present, so no
  per-tool wiring or rebuild is needed.

## Hard rules

- No plaintext secrets, ever — no hashed passwords, tokens, or private keys in Nix
  files or anywhere else in the repo. Encrypted secrets would need sops-nix/agenix
  (not set up). Per-machine SSH keys are generated outside the repo with
  `generate-ssh-key` (see `home/ssh.nix`).
- Git identity is the GitHub noreply address (`home/git.nix`); pushes with a private
  email are rejected by GitHub (GH007).
