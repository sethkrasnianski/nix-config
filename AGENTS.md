# nix-config

Flake-based NixOS config. Four outputs: `nixos` (WSL host, GNOME), `nixos-headless`
(same WSL host, no desktop), `nixos-default` (non-WSL template) — where home-manager
runs as a NixOS module, one rebuild applies system and user config together — and
`macbook` (a Mac, aarch64-darwin, managed by nix-darwin with home-manager as a
darwin module and nix-homebrew for the GUI apps nixpkgs can't build on darwin).

## Layout

See [Repository layout](docs/layout.md) for the authoritative directory tree and
file roles. See [Applications](docs/applications.md) for the platform matrix and
installation notes.

## Architecture

- `lib/mk-host.nix` composes the base, host, context modules, and local settings.
  Context repositories stay separate from this public repository.
- Hosts own platform selection, accounts, graphical mode, state versions, and
  Home Manager user wiring. The `nixos-default` template has no Home Manager user
  by default.
- NixOS system modules and nix-darwin system modules stay separate.
  `modules/common.nix` serves NixOS. `modules/darwin.nix` serves macOS.
  Both import `pkgs/overlay.nix` for custom packages and pinned overrides.
  Keep their unfree allowlists in sync.
- `home/default.nix` defines shared per-user configuration.
  `home/linux.nix` and `home/darwin.nix` add platform packages and
  `home.stateVersion`. Hosts supply the user identity.
- Home Manager links Doom configuration, agent settings, and shared agent files
  to this checkout. Edit their repository sources so changes apply without a
  rebuild.

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
  Keep the tree selective, and compare documented paths with `git ls-files --cached`.
- Align all tree comments in one column, with at least two spaces after the
  longest commented path.
  Keep four-column tree indentation and use spaces for padding.
  If a longer commented path needs room, move all comments to a later column together.
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
  no configuration is ever duplicated. Prime Agent is the
  exception so far — it globs `~/.agents/skills/` itself, so it needs no
  alias at all.
- A skill is a directory containing a `SKILL.md`: YAML frontmatter with `name`
  and `description` (the description is what triggers invocation — write it
  for matching), followed by the instructions.
- Adding or editing a skill needs no rebuild (the directory is live-symlinked);
  only creating the two links required the one initial `rebuild`.
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
