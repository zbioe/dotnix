;; -*- no-byte-compile: t; -*-
;;; packages.el

;; built by Nix with their native parts (home/editors/emacs.nix)
(package! vterm :built-in 'prefer)
(package! pdf-tools :built-in 'prefer)

(package! mermaid-mode)
(package! base16-theme)
(package! solaire-mode :disable t)

;; maps: OpenStreetMap in a buffer, and org-roam's notes as a graph
(package! osm)
(package! org-roam-ui)
