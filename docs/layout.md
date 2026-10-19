# Repository layout

[README](../README.md) · [Applications](applications.md)

This tree describes the main tracked files and directories. It groups some files
and leaves directory contents collapsed where a short description is enough.

```text
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
├── docs/
│   ├── layout.md                   # repository structure and file roles
│   └── applications.md             # application matrix and installation notes
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
    ├── .skill-lock.json                 # source and hash of upstream skills, written by gh skill
    └── skills/
        ├── code-search/SKILL.md    # skill: semantic and literal code search
        ├── new-project/SKILL.md    # skill: bootstrap a new project (flake, direnv, AGENTS.md, docs)
        ├── handoff/SKILL.md        # skill: compact the conversation into a handoff doc for another agent
        ├── explain-diff/SKILL.md   # skill: rich HTML explanation of a diff, branch, or PR
        ├── gh-stack/                    # stacked PRs with gh-stack, vendored from github/gh-stack
        │   ├── SKILL.md
        │   └── references/              # command reference, stack design, troubleshooting
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
