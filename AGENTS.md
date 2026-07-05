# nixos-config

Flake-based NixOS config. Four outputs: `nixos` (WSL host, GNOME), `nixos-headless`
(same WSL host, no desktop), `nixos-default` (non-WSL template) — where home-manager
runs as a NixOS module, one rebuild applies system and user config together — and
`macbook` (standalone home-manager for a Mac, aarch64-darwin, home directory only).

## Layout

- `flake.nix` — inputs: nixpkgs (nixos-unstable), nixos-wsl, home-manager (all pinned by `flake.lock`)
- `.github/workflows/update-flake-lock.yml` — weekly `flake.lock` update PR; evaluates all three outputs before opening it
- `hosts/` — per-host: hostname, `system.stateVersion`, home-manager user wiring
- `modules/` — system-level shared config (`common.nix`, `desktop.nix`, `wsl.nix`)
- `home/` — per-user home-manager config (git, ssh, shell, direnv, neovim, emacs);
  `default.nix` is the shared core, `linux.nix`/`darwin.nix` the per-platform
  entrypoints (NixOS hosts import `linux.nix`; the `macbook` output imports
  `darwin.nix`, which owns the macOS username, unfree allowlist, and stand-ins
  for the system layer — never import it from a NixOS host)
- `doom/`, `claude/settings.json`, `agents/`, `opencode/` — Doom Emacs, Claude
  Code, tool-agnostic agent config, and OpenCode-specific agents/commands/skills,
  live-symlinked into `$HOME` (`home/default.nix`); edits apply without a
  rebuild

## Working in this repo

- Apply changes: `rebuild` (= `sudo nixos-rebuild switch --flake ~/oss/nixos-config#nixos`);
  `rebuild-headless` for the headless variant.
- Check without switching — all four outputs must evaluate:
  `nix eval .#nixosConfigurations.<name>.config.system.build.toplevel.drvPath --raw`
  and `nix eval .#homeConfigurations.macbook.activationPackage.drvPath --raw`
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
- When adding, removing, or moving files under `modules/`, `home/`, or `hosts/`,
  update the Layout tree in `README.md` in the same commit — it duplicates this
  section's file listing and drifts silently otherwise.

## Agent skills

- Skills are tool-agnostic. The single source of truth is
  `agents/skills/<name>/SKILL.md`, exposed at `~/.agents` (the universal
  agent-config dir). Claude Code consumes them only through an alias —
  `~/.claude/skills` → `~/.agents/skills` (`home/default.nix`). Wire any new
  agent CLI the same way: give it an alias into `~/.agents`, never a copy, so
  no configuration is ever duplicated.
- A skill is a directory containing a `SKILL.md`: YAML frontmatter with `name`
  and `description` (the description is what triggers invocation — write it
  for matching), followed by the instructions.
- Adding or editing a skill needs no rebuild (the directory is live-symlinked);
  only creating the two links required the one initial `rebuild`.
- OpenCode-specific auto-agent changes belong under `opencode/`. Improve the
  smallest relevant agent, command, or skill, preserve the approval/TDD/review
  boundaries, and run `opencode/tests/` before evaluating the flake outputs.

## Hard rules

- No plaintext secrets, ever — no hashed passwords, tokens, or private keys in Nix
  files or anywhere else in the repo. Encrypted secrets would need sops-nix/agenix
  (not set up). Per-machine SSH keys are generated outside the repo with
  `generate-ssh-key` (see `home/ssh.nix`).
- Git identity is the GitHub noreply address (`home/git.nix`); pushes with a private
  email are rejected by GitHub (GH007).
