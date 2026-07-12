# Per-user (home-manager) configuration. Applied through the NixOS module —
# `rebuild` covers it, there is no separate home-manager switch.
{ config, pkgs, ... }:

{
  imports = [
    ./direnv.nix
    ./git.nix
    ./ssh.nix
    ./shell.nix
    ./neovim.nix
    ./emacs.nix
    ./ghostty.nix
  ];

  # Release home-manager state was first created with. Do not bump on upgrades.
  home.stateVersion = "25.11";

  # Terminals used with this setup (Windows Terminal, Ghostty) support 24-bit
  # color but do not all advertise it. COLORTERM makes TUI apps (e.g.
  # `emacs -nw`) render truecolor instead of approximating the theme with
  # the 256-color palette.
  home.sessionVariables.COLORTERM = "truecolor";

  # User-facing apps. Base CLI tools stay in modules/common.nix.
  # Ghostty is installed by programs.ghostty (home/ghostty.nix).
  home.packages = with pkgs; [
    opencode

    # unfree (allowed in modules/common.nix; useGlobalPkgs makes it apply here)
    claude-code
    ngrok
  ];

  # Doom Emacs reads its user config from ~/.config/doom; point that at the
  # real config (init.el / config.el / packages.el) tracked in this repo
  # (doom/). Claude Code's and OpenCode's global settings are tracked here too
  # (claude/, opencode/); OpenCode's agents, commands, and skills are linked
  # individually so its other state remains mutable.
  # mkOutOfStoreSymlink links to the checkout itself, so edits take effect
  # without a rebuild.
  home.file.".config/doom".source =
    config.lib.file.mkOutOfStoreSymlink "/home/nixos/oss/nixos-config/doom";
  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "/home/nixos/oss/nixos-config/claude/settings.json";
  home.file.".config/opencode/opencode.jsonc".source =
    config.lib.file.mkOutOfStoreSymlink "/home/nixos/oss/nixos-config/opencode/opencode.jsonc";
  home.file.".config/opencode/agents".source =
    config.lib.file.mkOutOfStoreSymlink "/home/nixos/oss/nixos-config/opencode/agents";
  home.file.".config/opencode/commands".source =
    config.lib.file.mkOutOfStoreSymlink "/home/nixos/oss/nixos-config/opencode/commands";
  home.file.".config/opencode/skills".source =
    config.lib.file.mkOutOfStoreSymlink "/home/nixos/oss/nixos-config/opencode/skills";
  home.file.".local/bin/auto-pr-watch" = {
    text = ''
      #!/bin/sh
      exec /home/nixos/oss/nixos-config/opencode/scripts/pr-watch.sh "$@"
    '';
    executable = true;
  };
  home.file.".local/bin/auto-history-finalize" = {
    text = ''
      #!/bin/sh
      exec /home/nixos/oss/nixos-config/opencode/scripts/history-finalize.sh "$@"
    '';
    executable = true;
  };

  # Tool-agnostic agent config (skills) — source of truth in agents/, exposed
  # at ~/.agents. Claude Code doesn't read ~/.agents natively, so it's proxied
  # with an alias: ~/.claude/skills → ~/.agents/skills. Other agent CLIs get
  # their own alias; never copy skills into a tool-specific directory.
  home.file.".agents".source =
    config.lib.file.mkOutOfStoreSymlink "/home/nixos/oss/nixos-config/agents";
  home.file.".claude/skills".source =
    config.lib.file.mkOutOfStoreSymlink "/home/nixos/.agents/skills";

  # Global agent instructions — single source of truth in agents/AGENTS.md,
  # aliased into each tool's expected path. Claude Code reads ~/.claude/CLAUDE.md;
  # opencode reads ~/.config/opencode/AGENTS.md. Both point at ~/.agents so the
  # instructions are never duplicated and edits apply without a rebuild.
  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "/home/nixos/.agents/AGENTS.md";
  home.file.".config/opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "/home/nixos/.agents/AGENTS.md";
}
