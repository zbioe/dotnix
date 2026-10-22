;;; init.el -*- lexical-binding: t; -*-

;; `doom sync` after changing this file (the doom-sync user service does it
;; at the next home switch)

(doom! :input

       :completion
       (corfu +orderless +icons +dabbrev)
       (vertico +icons)

       :ui
       doom
       dashboard
       (emoji +unicode)
       hl-todo
       indent-guides
       ligatures
       modeline
       nav-flash
       ophints
       (popup +defaults)
       (vc-gutter +pretty)
       vi-tilde-fringe
       window-select
       workspaces
       zen
       xwidgets

       :editor
       (evil +everywhere)
       file-templates
       fold
       (format +onsave)
       multiple-cursors
       rotate-text
       snippets
       (whitespace +guess +trim)
       word-wrap

       :emacs
       (dired +icons)
       electric
       (ibuffer +icons)
       tramp
       (undo +tree)
       vc

       :term
       eshell
       vterm

       :checkers
       (syntax +icons)
       (spell +flyspell +aspell)
       grammar

       :tools
       ansible
       (debugger +lsp)
       direnv
       (docker +lsp)
       editorconfig
       (eval +overlay)
       (lookup +dictionary)
       (lsp +peek)
       (magit +forge)
       make
       pdf
       (terraform +lsp)
       tree-sitter

       :os

       :lang
       data
       (elixir +lsp +tree-sitter)
       emacs-lisp
       (erlang +lsp)
       (go +lsp +tree-sitter)
       graphviz
       (javascript +lsp +tree-sitter)
       (json +lsp +tree-sitter)
       (latex +lsp +latexmk +cdlatex)
       (lua +lsp +tree-sitter)
       (markdown +grip)
       (nix +lsp +tree-sitter)
       (org +pretty +roam +gnuplot +dragndrop +present +pandoc +noter +journal +pomodoro)
       plantuml
       (python +lsp +pyright +tree-sitter)
       rest
       (rust +lsp +tree-sitter)
       (sh +lsp +fish +tree-sitter)
       (web +lsp +tree-sitter)
       (yaml +lsp +tree-sitter)

       :email
       (mu4e +org +gmail)

       :app
       calendar
       (rss +org)

       :config
       (default +bindings +smartparens))
