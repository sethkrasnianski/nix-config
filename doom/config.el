;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'one-dark)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;;; Soften diff highlighting.
;; agent-shell's inline diffs (and any `diff-mode' buffer) inherit Emacs'
;; default `diff-added'/`diff-removed' (and their `-refine-' word-level)
;; faces, which one-dark doesn't theme. The default refine backgrounds
;; (#22aa22 green, #aa2222 red) are harshly saturated against the dark
;; backdrop; desaturate both the line and word-level colors into muted tones
;; that sit in the one-dark palette (background #282C34, green #98C379,
;; red #BE5046).
(custom-set-faces!
  '(diff-added          :background "#2c352b" :foreground unspecified)
  '(diff-refine-added   :background "#3c4f38" :foreground unspecified)
  '(diff-removed        :background "#352b2b" :foreground unspecified)
  '(diff-refine-removed :background "#4f3838" :foreground unspecified))

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `with-eval-after-load' block, otherwise Doom's defaults may override your
;; settings. E.g.
;;
;;   (with-eval-after-load 'PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look them up).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.


;;; Tailwind CSS language server
;; Doom's lsp-tailwindcss client launches `node <tailwindServer.js> --stdio`,
;; but lsp-mode's "is the server installed?" check only runs `executable-find`
;; on the first command word -- `node` -- not the server itself. So it reports
;; the server as "Already installed", never downloads it, then errors out with
;; "Server tailwindcss:NNNN/starting exited" because the JS file is missing.
(after! lsp-tailwindcss
  ;; 1. Make the presence check look for the actual server binary, so lsp's
  ;;    normal install/launch lifecycle behaves correctly. `:test?` already
  ;;    exists in the stdio connection plist, so `plist-put` mutates it in place
  ;;    (no `setf` on the struct accessor needed).
  (when-let* ((client (gethash 'tailwindcss lsp-clients)))
    (plist-put (lsp--client-new-connection client)
               :test? (lambda ()
                        (file-exists-p (lsp-tailwindcss-server-command)))))
  ;; 2. Auto-install the server (once) into Doom's data dir if it's missing, so
  ;;    a fresh machine just works without a manual `M-x lsp-install-server`.
  (unless (file-exists-p (lsp-tailwindcss-server-command))
    (lsp-install-server nil 'tailwindcss)))


;;; Yank a code reference (@file#Lstart-end) for the selected lines.
;; Handy for pasting file:line references into Claude Code, PRs, chat, etc.
(defun +yank-code-reference ()
  "Copy an `@file#Lstart-end' reference for the active region to the clipboard.
Uses the buffer's file name (basename only) and the line numbers spanned by the
selection, e.g. `@server.py#L20-35'.  A single-line selection yields `@file#L20'."
  (interactive)
  (unless (region-active-p)
    (user-error "No active region; select some lines first"))
  (let* ((name (file-name-nondirectory (or (buffer-file-name) (buffer-name))))
         (beg (region-beginning))
         (end (region-end))
         (beg-line (line-number-at-pos beg))
         ;; If the region ends at the very start of a line, that line isn't
         ;; actually selected (common with line-wise visual selections), so
         ;; count up to the previous line.
         (end-line (line-number-at-pos
                    (if (and (> end beg)
                             (= end (save-excursion
                                      (goto-char end)
                                      (line-beginning-position))))
                        (1- end)
                      end)))
         (ref (if (= beg-line end-line)
                  (format "@%s#L%d" name beg-line)
                (format "@%s#L%d-%d" name beg-line end-line))))
    (kill-new ref)
    (gui-set-selection 'CLIPBOARD ref)
    (message "Copied: %s" ref)))

(map! :leader
      (:prefix ("y" . "Yank")
       :desc "code" "c" #'+yank-code-reference)
      :desc "Focus Treemacs"  "op" #'treemacs-select-window
      (:prefix "g"
       :desc "Magit status"   "s" #'magit-status
       :desc "Stage hunk"     "g" #'diff-hl-stage-current-hunk)
      (:prefix "b"
       :desc "Scratch buffer" "e" #'doom/open-scratch-buffer)
      ;; SPC a is `embark-act' (labeled "Actions" by the vertico module).
      ;; Making it a prefix re-homes embark-act to SPC a a; C-; still
      ;; invokes it everywhere. The unbind must come first: keys can't be
      ;; nested under a key that is already bound to a command.
      "a" nil
      (:prefix ("a" . "Actions")
       :desc "Embark act" "a" #'embark-act
       (:prefix ("s" . "agent-shell")
        :desc "Default (Claude Code)" "s" #'agent-shell
        :desc "opencode"              "d" #'agent-shell-opencode-start-agent)))


;;; Sync the kill ring with the system clipboard (macOS and WSL).
;; A GUI frame already talks to the system clipboard, but a terminal frame
;; (`emacs -nw' / `emacsclient -t') has no clipboard access on its own. Routing
;; the kill ring through an external clipboard tool covers both -- and a daemon
;; serving a mix of GUI and tty frames -- since the tool behaves the same
;; regardless of frame type. With this, every Evil yank/delete (and Emacs kill)
;; lands on the system clipboard.
(setq select-enable-clipboard t)
;; Don't overwrite the clipboard/register when pasting over a visual selection.
(after! evil
  (setq evil-kill-on-visual-paste nil))
(when (executable-find "pbcopy")
  (defun +pbcopy (text &optional _push)
    "Send TEXT to the macOS clipboard via pbcopy."
    (let ((process-connection-type nil))
      (let ((proc (start-process "pbcopy" nil "pbcopy")))
        (process-send-string proc text)
        (process-send-eof proc))))
  (defun +pbpaste ()
    "Return the macOS clipboard contents via pbpaste."
    (shell-command-to-string "pbpaste"))
  (setq interprogram-cut-function #'+pbcopy
        interprogram-paste-function #'+pbpaste))

;; Same idea on WSL: route kills to the Windows clipboard via clip.exe (on
;; PATH through WSL interop), covering GUI (WSLg) and tty frames alike --
;; WSLg's own clipboard bridge is unreliable. clip.exe accepts UTF-8 as-is
;; on this setup (UTF-16 is what garbles, tested), so no re-encoding. Only
;; the cut direction is routed: paste already works via WSLg in GUI frames
;; and the terminal's paste in tty frames, and an interprogram-paste-function
;; would have to spawn powershell.exe on every yank, which is slow.
(when (and (getenv "WSL_DISTRO_NAME") (executable-find "clip.exe"))
  (defun +wsl-clip (text &optional _push)
    "Send TEXT to the Windows clipboard via clip.exe."
    (let ((process-connection-type nil))
      (let ((proc (start-process "clip" nil "clip.exe")))
        (process-send-string proc text)
        (process-send-eof proc))))
  (setq interprogram-cut-function #'+wsl-clip))


;;; agent-shell -- AI coding agents in Emacs over ACP, set up for Claude Code.
;; The Claude ACP adapter (claude-agent-acp) is provided by modules/emacs.nix,
;; plus a logged-in Claude CLI (run `claude` once outside Emacs to authenticate).
;; Start a session with `M-x agent-shell-anthropic-start-claude-code' (or
;; `M-x agent-shell', which defaults to Claude Code via the config below).
(use-package! agent-shell
  :defer t
  :config
  ;; Reuse the existing Claude subscription login. To use an API key instead:
  ;;   (agent-shell-anthropic-make-authentication :api-key "sk-ant-...")
  (setq agent-shell-anthropic-authentication
        (agent-shell-anthropic-make-authentication :login t))
  ;; Make `M-x agent-shell' default to Claude Code.
  (setq agent-shell-preferred-agent-config
        (agent-shell-anthropic-make-claude-code-config)))
