;;; init.el -*- lexical-binding: t; -*-

(doom! :input
       :completion
       company
       vertico

       :ui
       doom
       doom-dashboard
       hl-todo
       modeline
       ophints
       (popup +defaults)
       treemacs
       vc-gutter
       vi-tilde-fringe
       workspaces

       :editor
       (evil +everywhere)
       file-templates
       fold
       snippets

       :emacs
       dired
       electric
       ibuffer
       undo
       vc

       :term
       eshell

       :checkers
       syntax

       :tools
       (eval +overlay)
       lookup
       lsp
       magit

       :os
       tty

       :lang
       emacs-lisp
       json
       markdown
       nix
       org
       sh
       yaml

       :config
       (default +bindings +smartparens))
