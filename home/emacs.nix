# Emacs + Doom. The editor itself is declarative; Doom manages its own
# packages with straight.el, so the framework is bootstrapped imperatively
# once (see the README "Emacs (Doom)" section):
#
#   git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.config/emacs
#   doom install
#
# The private Doom config (init.el / config.el / packages.el) lives in doom/
# at this repo's root; ~/.config/doom is symlinked to it in home/default.nix
# so Doom picks up exactly those files. Doom's external tools are ripgrep/fd
# from modules/common.nix and git from home/git.nix. The icon font Doom's UI
# needs stays system-level (modules/common.nix).
{ pkgs, ... }:

let
  treesitGrammars = pkgs.emacsPackages.treesit-grammars.with-grammars (grammars: [
    grammars.tree-sitter-tsx
    grammars.tree-sitter-typescript
  ]);
in
{
  home.packages = with pkgs; [
    # `emacs` tracks the newest release in nixpkgs (30.2 as of this writing),
    # unlike a version-pinned attribute such as `emacs30`.
    emacs

    # Doom module dependencies (flagged by `doom doctor`):
    nodejs # :tools lsp server auto-install (also needs unzip, from common.nix)
    typescript # Provides tsserver, required by typescript-language-server
    typescript-language-server # :lang javascript (+lsp) TypeScript/JavaScript LSP
    shellcheck # :lang sh linting
    claude-agent-acp # Claude ACP adapter for agent-shell (see doom/config.el)
    nil # :lang nix (+lsp) language server; formatting uses nixfmt (common.nix)
    yaml-language-server # :lang yaml (+lsp) language server
    rust-analyzer # :lang rust (+lsp) language server
    svelte-language-server # :lang web (+lsp) Svelte language server
    # :lang rust (+tree-sitter): Doom compiles the grammar at runtime via
    # `treesit-install-language-grammar`, which needs a C compiler (`cc`).
    gcc

    # Prebuilt TypeScript and TSX grammars for native tree-sitter modes.
    treesitGrammars
  ];

  # Keep grammars in the Nix store instead of compiling them into Doom's
  # mutable data directory at runtime.
  home.sessionVariables.EMACS_TREESIT_LOAD_PATH = "${treesitGrammars}/lib";

  # Doom's CLI (`doom sync`, `doom doctor`, ...) lives inside the framework
  # checkout, which isn't a Nix package — put it on PATH.
  home.sessionPath = [ "$HOME/.config/emacs/bin" ];
}
