# Per-user (home-manager) configuration shared by every machine. Not imported
# directly: each platform has a thin entrypoint — home/linux.nix (NixOS module,
# applied by `rebuild`) and home/darwin.nix (standalone home-manager on macOS)
# — that carries the per-machine facts (stateVersion, username, ...).
{ config, pkgs, ... }:

let
  # The checkout of this repo, assumed at the same place on every machine.
  flakePath = "${config.home.homeDirectory}/oss/nixos-config";
in
{
  imports = [
    ./direnv.nix
    ./git.nix
    ./ssh.nix
    ./shell.nix
    ./neovim.nix
    ./emacs.nix
    ./ghostty.nix
    ./photogimp.nix
  ];

  # NOTE: home.stateVersion is per-machine and lives in the entrypoints
  # (linux.nix / darwin.nix). Never bump it on upgrades.

  # Terminals used with this setup (Windows Terminal, Ghostty) support 24-bit
  # color but do not all advertise it. COLORTERM makes TUI apps (e.g.
  # `emacs -nw`) render truecolor instead of approximating the theme with
  # the 256-color palette.
  home.sessionVariables.COLORTERM = "truecolor";

  # User-facing apps shared by every machine (Linux and macOS). Platform-only
  # apps live in the entrypoints (home/linux.nix, home/darwin.nix); base CLI
  # tools stay in modules/common.nix (NixOS) / modules/darwin.nix (macOS).
  # Ghostty is installed by programs.ghostty (home/ghostty.nix).
  home.packages = with pkgs; [
    opencode
    doctl

    # unfree — allowed on NixOS via modules/common.nix and on macOS via
    # modules/darwin.nix (both use useGlobalPkgs, so the predicate reaches
    # home.packages). Keep those two allowlists in sync.
    claude-code
    ngrok
    spotify
    obsidian
  ];

  # Doom Emacs reads its user config from ~/.config/doom; point that at the
  # real config (init.el / config.el / packages.el) tracked in this repo
  # (doom/). Claude Code's and OpenCode's global settings are tracked here too
  # (claude/, opencode/); OpenCode's agents, commands, and skills are linked
  # individually so its other state remains mutable.
  # mkOutOfStoreSymlink links to the checkout itself, so edits take effect
  # without a rebuild.
  home.file.".config/doom".source = config.lib.file.mkOutOfStoreSymlink "${flakePath}/doom";
  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${flakePath}/claude/settings.json";
  home.file.".config/opencode/opencode.jsonc".source =
    config.lib.file.mkOutOfStoreSymlink "${flakePath}/opencode/opencode.jsonc";
  home.file.".config/opencode/agents".source =
    config.lib.file.mkOutOfStoreSymlink "${flakePath}/opencode/agents";
  home.file.".config/opencode/commands".source =
    config.lib.file.mkOutOfStoreSymlink "${flakePath}/opencode/commands";
  home.file.".config/opencode/skills".source =
    config.lib.file.mkOutOfStoreSymlink "${flakePath}/opencode/skills";
  home.file.".local/bin/auto-pr-watch" = {
    text = ''
      #!/bin/sh
      exec ${flakePath}/opencode/scripts/pr-watch.sh "$@"
    '';
    executable = true;
  };
  home.file.".local/bin/auto-history-finalize" = {
    text = ''
      #!/bin/sh
      exec ${flakePath}/opencode/scripts/history-finalize.sh "$@"
    '';
    executable = true;
  };

  # Tool-agnostic agent config (skills) — source of truth in agents/, exposed
  # at ~/.agents. Claude Code doesn't read ~/.agents natively, so it's proxied
  # with an alias: ~/.claude/skills → ~/.agents/skills. Other agent CLIs get
  # their own alias; never copy skills into a tool-specific directory.
  home.file.".agents".source = config.lib.file.mkOutOfStoreSymlink "${flakePath}/agents";
  home.file.".claude/skills".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/skills";

  # Global agent instructions — single source of truth in agents/AGENTS.md,
  # aliased into each tool's expected path. Claude Code reads ~/.claude/CLAUDE.md;
  # opencode reads ~/.config/opencode/AGENTS.md. Both point at ~/.agents so the
  # instructions are never duplicated and edits apply without a rebuild.
  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/AGENTS.md";
  home.file.".config/opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/AGENTS.md";
}
