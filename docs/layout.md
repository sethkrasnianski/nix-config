# Repository layout

[README](../README.md) · [Applications](applications.md)

This tree describes the main tracked files and directories. It groups some files
and leaves directory contents collapsed where a short description is enough.
Paths are relative to the repository root. Follow the
[maintenance rules](../AGENTS.md#working-in-this-repo) when the layout changes.

```text
.
├── .github/
│   ├── scripts/
│   │   └── update-synergy3.sh           # fetches guest tokens and hashes Linux and macOS installers
│   └── workflows/
│       ├── update-flake-lock.yml        # weekly lock-update PR after context tests and all four output evaluations
│       ├── check-config.yml             # context integration tests and all four output evaluations on PRs
│       └── update-synergy3.yml          # weekly installer version/hash PR after validation and output evaluations
├── AGENTS.md                            # repository instructions and documentation maintenance rules
├── CLAUDE.md                            # forwards Claude Code to the repository instructions
├── README.md                            # overview, setup, daily use, and links to reference documentation
├── flake.nix                            # pinned inputs, four host outputs, and the shared host factory export
├── flake.lock                           # input revisions for reproducible builds
├── docs/
│   ├── layout.md                        # authoritative repository tree and file roles
│   └── applications.md                  # selected application matrix and installation notes
├── lib/
│   └── mk-host.nix                      # shared factory for public outputs and private context compositions
├── contexts/
│   └── template/                        # portable context flake with Home Manager and OS modules
├── local-config/
│   └── default.nix                      # safe default for the replaceable local-config input, with Ollama disabled
├── tests/
│   ├── contexts-eval.nix                # cross-platform context composition checks
│   ├── workspace-eval.nix               # actual Git profile definitions for integration tests
│   ├── check.sh                         # context tests and all four output evaluations
│   ├── config_test.py                   # CLI lifecycle tests and opt-in Nix integration
│   ├── environments_test.py             # generated-file ownership and direnv inheritance
│   └── workspace_test.py                # folder-scoped Git identities and linked worktrees
├── pkgs/
│   ├── overlay.nix                      # custom packages and pinned nixpkgs overrides, shared by both system layers
│   ├── prime-agent/                     # pinned native Rust releases for Linux and Apple Silicon
│   └── synergy3/                        # pinned Flatpak/DMG installers with hash-verified guest-token fetching
├── modules/
│   ├── contexts.nix                     # context metadata, user selection, and generation manifest
│   ├── common.nix                       # NixOS system settings, overlays, CLI tools, unfree allowlist, zsh, and fonts
│   ├── desktop.nix                      # GNOME and Steam, gated by local.graphical.enable
│   ├── synergy3.nix                     # system Flatpak activation on every NixOS host, including without Home Manager
│   ├── synergy3-darwin.nix              # copies Synergy.app to /Applications, as its macOS service requires
│   ├── wsl.nix                          # WSL-only user, runtime directory, sudo, and network integration
│   ├── git-ignores.nix                  # shared ignore patterns for system Git and home/git.nix
│   ├── darwin.nix                       # macOS system settings, overlays, CLI tools, unfree allowlist, fonts, and Homebrew
│   ├── primary-user.nix                 # macOS local.primaryUser option, overridable through local.nix
│   ├── local-agents.nix                 # typed host-local OpenCode inference overrides
│   ├── local-llm.nix                    # optional host-local Ollama and OpenCode routing
│   ├── local-llm-nixos.nix              # NixOS Ollama service wiring
│   └── local-llm-darwin.nix             # nix-darwin Ollama launchd wiring
├── hosts/
│   ├── nixos-wsl.nix                    # WSL system and Home Manager user for nixos and nixos-headless
│   ├── nixos-default.nix                # non-WSL hardware template, with no Home Manager user by default
│   ├── nixos-default-hardware.nix       # placeholder to replace with nixos-generate-config output
│   └── macbook.nix                      # macOS primary user, system layer, Synergy activation, Home Manager, and Dock
├── home/                                # per-user Home Manager configuration
│   ├── config.nix                       # config command with Python, Git, and Nix runtime tools
│   ├── contexts.nix                     # ownership-checked context environments from locked compositions
│   ├── workspace.nix                    # folder-scoped Git identities, with nested profiles
│   ├── default.nix                      # shared imports, user packages, and managed configuration symlinks
│   ├── linux.nix                        # Linux packages and home.stateVersion for the configured NixOS user
│   ├── darwin.nix                       # macOS packages, Docker plugin links, and home.stateVersion
│   ├── git.nix                          # user Git settings and global ignore file
│   ├── ssh.nix                          # SSH settings, agent, and per-machine key helper
│   ├── shell.nix                        # Bash, Zsh, and agent shell wrappers
│   ├── direnv.nix                       # direnv hooks and Nix project environments
│   ├── neovim.nix                       # Neovim configuration
│   ├── emacs.nix                        # Emacs package and Doom CLI path
│   ├── ghostty.nix                      # Ghostty package selection and shared keybindings
│   └── photogimp.nix                    # seeds writable GIMP configuration from a pinned PhotoGIMP release
├── doom/                                # Doom user configuration, linked from ~/.config/doom
├── claude/
│   └── settings.json                    # global Claude Code settings, linked from ~/.claude/settings.json
├── prime/
│   └── settings.json                    # global Prime Agent settings, linked from ~/.prime/agent/settings.json
├── opencode/
│   ├── opencode.jsonc                   # global OpenCode settings
│   ├── agent-defaults.nix               # repository-owned model and inference profiles
│   ├── local-profile.nix                # startup evaluator for ~/.config/nix/local.nix
│   ├── tui.json                         # global OpenCode UI theme
│   ├── agents/                          # OpenCode auto-agent definitions
│   ├── commands/                        # /auto, /research, /plan, and related commands
│   ├── skills/                          # OpenCode auto-agent skills
│   ├── plugins/                         # OpenCode runtime plugins
│   ├── scripts/                         # PR watcher and history finalizer helpers
│   ├── tests/                           # auto-agent contract tests
│   ├── install.sh                       # standalone per-item symlink installer and uninstaller
│   └── README.md                        # auto-agent usage and maintenance guide
├── scripts/
│   ├── config.py                        # context registration, locked compositions, status, check, and rebuild
│   ├── context_envrcs.py                # generated .envrc ownership, replacement, and removal
│   └── rebuild-local.sh                 # bootstrap wrapper for the config command
└── agents/                              # shared agent configuration, linked from ~/.agents
    ├── AGENTS.md                        # canonical global instructions, aliased into each agent tool
    ├── mcp.json                         # shared MCP servers, passed to Claude Code through its shell wrapper
    ├── .skill-lock.json                 # source and hash of upstream skills, written by gh skill
    └── skills/
        ├── code-search/SKILL.md         # semantic and literal code search
        ├── new-project/SKILL.md         # project setup with a flake, direnv, agent instructions, and documentation
        ├── handoff/SKILL.md             # handoff document for another agent
        ├── explain-diff/SKILL.md        # HTML explanation of a diff, branch, or PR
        ├── gh-stack/                    # stacked PRs with gh-stack, vendored from github/gh-stack
        │   ├── SKILL.md
        │   └── references/              # command reference, stack design, troubleshooting
        ├── please-continue/SKILL.md     # resumes interrupted work after sleep or a stalled session
        ├── ste-writing/                 # Simplified Technical English guidance and prose checker
        │   ├── SKILL.md
        │   └── scripts/ste-lint.py      # mechanical prose checks, run with Python from nix shell
        └── tickets/                     # GitHub Projects V2 Kanban ticket workflow
            ├── SKILL.md
            ├── contracts/kanban-v1.json
            ├── fixtures/                # sanitized contract-verification fixtures
            ├── scripts/project-contract.sh
            └── tests/project-contract-test.sh
```
