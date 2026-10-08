# Single source of truth for the machine-wide git ignore list. Plain data (a
# list of patterns), not a module: modules/common.nix writes it to
# /etc/gitignore for every user on a NixOS host, and home/git.nix writes it to
# ~/.config/git/ignore for the home-manager user (on every host, including the
# Mac). Import it directly: `import ../modules/git-ignores.nix`.
#
# These are files that can hold secrets or host-specific state and must never be
# one 'git add -A' from a commit in any repo, including fresh clones whose
# tracked .gitignore lacks the entry.
[
  # agent-shell session transcripts — a pasted token or env dump can land here.
  ".agent-shell/"
  ".claude/worktrees/*"
  ".agents/worktrees/*"
  # Per-checkout, host-specific agent instructions.
  "CLAUDE.local.md"
  "AGENTS.local.md"
]
