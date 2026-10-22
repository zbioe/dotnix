;;; config.el -*- lexical-binding: t; -*-

;;; Look: `theme' and `theme font' (dotnix home/theme) write these; the
;;; settings above them are the fallback when never applied

(setq doom-theme 'doom-gruvbox)
(load (expand-file-name "theme/current/emacs.el"
                        (or (getenv "XDG_STATE_HOME") "~/.local/state"))
      t t)

(setq doom-font
      (cl-find-if #'doom-font-exists-p
                  '("Noto Sans Mono:pixelsize=20"
                    "GohuGohu:pixelsize=14"
                    "Iosevka Nerd Font:pixelsize=14")))
(load (expand-file-name "theme/font/emacs.el"
                        (or (getenv "XDG_STATE_HOME") "~/.local/state"))
      t t)

(setq display-line-numbers-type nil
      org-directory "~/org/")
(auto-fill-mode -1)

;; Doom generates autoloads only for what straight builds, not for the
;; packages Nix builds (home/editors/default.nix)
(dolist (pkg '("pdf-tools" "vterm"))
  (load (concat pkg "-autoloads") t t))

;;; Keys

(global-set-key (kbd "M-p") 'mark-paragraph)
(global-set-key (kbd "M-h") 'backward-kill-word)
(global-set-key (kbd "C-h") 'delete-backward-char)
(global-set-key (kbd "C-?") 'help-command)
(setq doom-leader-alt-key "C-,"
      doom-localleader-alt-key "C-<")

;; base64 encode without line breaks with a prefix argument
(defun base64-encode-region-prefix-arg (&rest _args)
  "Pass prefix arg as third arg to `base64-encode-region'."
  (interactive "r\nP"))
(advice-add 'base64-encode-region :before #'base64-encode-region-prefix-arg)

;;; Browser in a buffer

(setq xwidget-webkit-cookie-file "~/.local/share/xwidget-webkit-cookies.txt")
(after! evil-collection
  (evil-collection-init 'xwidget))
(after! xwidget
  (add-hook 'xwidget-webkit-mode-hook #'xwidget-webkit-edit-mode))

;;; Formatting: the same tools `nix fmt' and the checks use, never the LSP
;;; server's own formatter (it had nixd reformat Nix its own way)

(setq-hook! '(nix-mode-hook nix-ts-mode-hook) +format-with 'nixfmt)
(setq-hook! '(go-mode-hook go-ts-mode-hook) +format-with '(goimports gofumpt))
(setq-hook! '(sh-mode-hook bash-ts-mode-hook) +format-with 'shfmt)
(after! python
  (setq python-indent-offset 2))
(after! sh-script
  (setq sh-basic-offset 2))

;;; LSP: servers come from dotnix (system/packages/dev.nix)

(setq lsp-auto-guess-root t
      lsp-pyright-langserver-command "basedpyright"
      lsp-erlang-server 'erlang-language-platform)

(after! lsp-go
  (setq lsp-go-use-gofumpt t
        lsp-go-use-placeholders t
        lsp-go-analyses '((unusedparams . t)
                          (unusedwrite . t)
                          (nilness . t)
                          (shadow . t))))

;; nixd evaluates ~/dotnix: nixpkgs, NixOS and home-manager options of this host
(setq lsp-disabled-clients '(nix-nil)
      lsp-nix-nixd-nixpkgs-expr
      "import (builtins.getFlake \"/home/zbioe/dotnix\").inputs.nixpkgs { }"
      lsp-nix-nixd-nixos-options-expr
      (format "(builtins.getFlake \"/home/zbioe/dotnix\").nixosConfigurations.%s.options"
              (system-name))
      lsp-nix-nixd-home-manager-options-expr
      (format "(builtins.getFlake \"/home/zbioe/dotnix\").homeConfigurations.%s.options"
              (system-name)))

;;; Linters chained after the LSP diagnostics

(after! flycheck
  (flycheck-define-checker nix-statix
    "Nix anti-pattern linter, see https://github.com/oppiliappan/statix."
    :command ("statix" "check" "-o" "errfmt" source)
    :error-patterns
    ((error line-start (file-name) ">" line ":" column ":E:"
            (id (one-or-more digit)) ":" (message) line-end)
     (warning line-start (file-name) ">" line ":" column ":" (any "WHI") ":"
              (id (one-or-more digit)) ":" (message) line-end))
    :modes (nix-mode nix-ts-mode))
  (add-to-list 'flycheck-checkers 'nix-statix 'append))

(after! (:and flycheck lsp-diagnostics)
  (lsp-diagnostics-lsp-checker-if-needed)
  (flycheck-add-next-checker 'lsp 'dockerfile-hadolint)
  (flycheck-add-next-checker 'lsp 'nix-statix))

(after! (:and lsp-diagnostics flycheck-golangci-lint)
  (lsp-diagnostics-lsp-checker-if-needed)
  (flycheck-add-next-checker 'lsp 'golangci-lint))

;; Ansible's server only on Ansible files, not every YAML of a project with roles/
(defun +ansible-only-in-ansible-files-h ()
  (when (and +ansible-yaml-mode
             (not (string-match-p
                   (concat "/\\(?:ansible\\|roles\\|playbooks\\|group_vars\\|host_vars\\)/"
                           "\\|/\\(?:playbook\\|site\\)[^/]*\\.ya?ml\\'")
                   buffer-file-name)))
    (ansible-mode -1)
    (ansible-doc-mode -1)))
(add-hook '+ansible-yaml-mode-hook #'+ansible-only-in-ansible-files-h 'append)

;;; Debuggers (dap-mode): delve, debugpy and gdb come from dotnix

(after! dap-mode
  (setq dap-python-debugger 'debugpy)
  (require 'dap-dlv-go)
  (require 'dap-python)
  (require 'dap-gdb-lldb))

;;; Writing: English and Portuguese, grammar through LanguageTool

(after! ispell
  (setq ispell-program-name "aspell"
        ispell-dictionary "en_US"))
(after! langtool
  (setq langtool-bin "languagetool-commandline"
        langtool-default-language "en-US"))

;;; Diagrams and maps

(use-package! mermaid-mode
  :config
  (setq mermaid-mmdc-location "mmdc"))
(after! plantuml-mode
  (setq plantuml-default-exec-mode 'executable))
(after! org
  (setq org-plantuml-exec-mode 'plantuml
        org-roam-directory (expand-file-name "roam" org-directory)))
(use-package! osm
  :defer t
  :init (setq osm-home '(-23.55 -46.63 12)))
(use-package! org-roam-ui
  :after org-roam
  :config
  (setq org-roam-ui-sync-theme t
        org-roam-ui-follow t
        org-roam-ui-open-on-start nil))

;;; Mail: mu4e over mbsync; Proton through its Bridge on localhost (the
;;; password is in ~/.authinfo, from dotnix secrets/mail.yaml)

(after! auth-source
  (require 'auth-source-pass)
  (auth-source-pass-enable))

(after! gnutls
  (add-to-list 'gnutls-trustfiles (expand-file-name "~/.config/protonmail/bridge-v3/cert.pem")))

(setq mail-specify-envelope-from t
      mail-envelope-from 'header
      message-sendmail-envelope-from 'header)

(after! mu4e
  (setq mu4e-get-mail-command "mbsync -a"
        mu4e-update-interval (* 10 60)
        mu4e-user-mail-address-list
        '("zbioe@protonmail.com"
          "zbioe@proton.me"
          "zbioe@pm.me"
          "i@zbioe.com"
          "i@zagenda.me"
          "iuryfukuda@gmail.com"))
  (setq mu4e-contexts
        (list
         (make-mu4e-context
          :name "Proton"
          :match-func (lambda (msg)
                        (when msg
                          (string-prefix-p "/Proton" (mu4e-message-field msg :maildir))))
          :vars '((user-mail-address      . "i@zbioe.com")
                  (user-full-name         . "Iury")
                  (smtpmail-smtp-server   . "127.0.0.1")
                  (smtpmail-smtp-service  . 1025)
                  (smtpmail-smtp-user     . "zbioe@pm.me")
                  (smtpmail-stream-type   . starttls)))
         (make-mu4e-context
          :name "Gmail"
          :match-func (lambda (msg)
                        (when msg
                          (string-prefix-p "/Gmail" (mu4e-message-field msg :maildir))))
          :vars '((user-mail-address      . "iuryfukuda@gmail.com")
                  (user-full-name         . "Iury")
                  (smtpmail-smtp-server   . "smtp.gmail.com")
                  (smtpmail-smtp-service  . 587)
                  (smtpmail-smtp-user     . "iuryfukuda@gmail.com")
                  (smtpmail-stream-type   . starttls))))))

;;; Clipboard: Chromium (Wayland) pastes TEXT, which Emacs encodes as latin-1;
;;; offer only the UTF-8 targets so accents survive

(after! select
  (setq selection-converter-alist
        (seq-remove (lambda (e) (memq (car e) '(STRING TEXT COMPOUND_TEXT text/plain)))
                    selection-converter-alist)))
