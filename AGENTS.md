# nixos-config

Flake-based NixOS config. Three outputs: `nixos` (WSL host, GNOME), `nixos-headless`
(same WSL host, no desktop), `nixos-default` (non-WSL template). home-manager runs as
a NixOS module — one rebuild applies system and user config together.

## Layout

- `flake.nix` — inputs: nixpkgs (nixos-unstable), nixos-wsl, home-manager (all pinned by `flake.lock`)
- `hosts/` — per-host: hostname, `system.stateVersion`, home-manager user wiring
- `modules/` — system-level shared config (`common.nix`, `desktop.nix`, `wsl.nix`)
- `home/` — per-user home-manager config (git, ssh, shell, direnv, neovim, emacs)
- `doom/`, `claude/settings.json` — Doom Emacs and Claude Code configs, live-symlinked
  into `$HOME` (`home/default.nix`); edits apply without a rebuild

## Working in this repo

- Apply changes: `rebuild` (= `sudo nixos-rebuild switch --flake ~/personal/nixos-config#nixos`);
  `rebuild-headless` for the headless variant.
- Check without switching — all three outputs must evaluate:
  `nix eval .#nixosConfigurations.<name>.config.system.build.toplevel.drvPath --raw`
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

## Hard rules

- No plaintext secrets, ever — no hashed passwords, tokens, or private keys in Nix
  files or anywhere else in the repo. Encrypted secrets would need sops-nix/agenix
  (not set up). Per-machine SSH keys are generated outside the repo with
  `generate-ssh-key` (see `home/ssh.nix`).
- Git identity is the GitHub noreply address (`home/git.nix`); pushes with a private
  email are rejected by GitHub (GH007).
