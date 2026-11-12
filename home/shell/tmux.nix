{ config, ... }:
{
  programs.tmux = {
    enable = config.dotnix.shell.tmux.enable;
    sensibleOnTop = false;
    shortcut = "q";
    terminal = "screen-256color";
    resizeAmount = 8;
    extraConfig = ''
      set-option -g set-titles on
      set-option -g set-titles-string "Tmux - #S #T"
      setw -g automatic-rename-format "#{b:pane_current_path}"
      set-option -sg escape-time 10
      set-option -g focus-events on

      set -as terminal-features 'alacritty:sixel'
      set -g allow-passthrough on

      set -g default-terminal "alacritty"
      set-environment -gu TERMINFO
      set-option -ga terminal-overrides ",alacritty:Tc"

      # Color
      set -g status-bg black
      set -g status-fg white

      set-option -g pane-active-border-style bg=default,fg=white
      set -g pane-border-style fg=black
      set -g status-right '#H' # only host in right display

      set -g base-index 1

      bind C-b select-pane -L
      bind C-n select-pane -D
      bind C-p select-pane -U
      bind C-f select-pane -R

      bind-key M-n resize-pane -D 5
      bind-key M-p resize-pane -U 5
      bind-key M-b resize-pane -L 5
      bind-key M-f resize-pane -R 5

      bind c new-window  -c "#{pane_current_path}"
      bind h split-window -h -c "#{pane_current_path}"
      bind v split-window -v -c "#{pane_current_path}"

      bind k confirm-before kill-window
      bind K kill-window

      bind j confirm-before kill-pane
      bind J kill-pane

      bind ^[ copy-mode
      bind ^Y paste-buffer
      bind ^A last-window
      bind a last-window

      bind e 'attach -c "#{pane_current_path}"; display "default path setted"'
      bind w run "tmux save-buffer - | wl-copy"

      # Copy mode: Emacs keys first (C-n/p/f/b, C-a, M-f/b, C-v/M-v, M-</>,
      # C-s/C-r, C-Space, C-g, M-w), plus the Vim ones that don't take an
      # Emacs key, like evil's normal state. Every copy also goes to the
      # clipboard
      set -s copy-command 'wl-copy'
      # a line or half a page at a time (evil's C-e/C-y, C-d/C-u); the end
      # of the line stays on End and $
      bind -T copy-mode C-e send -X scroll-down
      bind -T copy-mode C-y send -X scroll-up
      bind -T copy-mode C-d send -X halfpage-down
      bind -T copy-mode C-u send -X halfpage-up
      bind -T copy-mode h send -X cursor-left
      bind -T copy-mode j send -X cursor-down
      bind -T copy-mode k send -X cursor-up
      bind -T copy-mode l send -X cursor-right
      bind -T copy-mode w send -X next-word
      bind -T copy-mode b send -X previous-word
      bind -T copy-mode e send -X next-word-end
      bind -T copy-mode W send -X next-space
      bind -T copy-mode B send -X previous-space
      bind -T copy-mode E send -X next-space-end
      bind -T copy-mode 0 send -X start-of-line
      bind -T copy-mode ^ send -X back-to-indentation
      bind -T copy-mode $ send -X end-of-line
      bind -T copy-mode H send -X top-line
      bind -T copy-mode M send -X middle-line
      bind -T copy-mode L send -X bottom-line
      bind -T copy-mode G send -X history-bottom
      bind -T copy-mode \{ send -X previous-paragraph
      bind -T copy-mode \} send -X next-paragraph
      bind -T copy-mode % send -X next-matching-bracket
      bind -T copy-mode \; send -X jump-again
      # gg to the top; g's goto-line moves to : (Vim's :N)
      bind -T copy-mode g switch-client -T copy-mode-g
      bind -T copy-mode-g g send -X history-top
      bind -T copy-mode : command-prompt -p "(goto line)" { send -X goto-line -- "%%" }
      bind -T copy-mode / command-prompt -i -I "#{pane_search_string}" -T search -p "(search down)" { send -X search-forward-incremental -- "%%" }
      bind -T copy-mode ? command-prompt -i -I "#{pane_search_string}" -T search -p "(search up)" { send -X search-backward-incremental -- "%%" }
      # select (v, a whole line V) and copy (y); Escape drops a selection
      # before leaving, i leaves like Vim's insert
      bind -T copy-mode v send -X begin-selection
      bind -T copy-mode V send -X select-line
      bind -T copy-mode y send -X copy-pipe-and-cancel
      bind -T copy-mode Y send -X copy-pipe-end-of-line-and-cancel
      bind -T copy-mode Escape if -F "#{selection_present}" { send -X clear-selection } { send -X cancel }
      bind -T copy-mode i send -X cancel
      bind r 'source-file ~/.config/tmux/tmux.conf; display "reloaded"'
      bind ^R send-keys 'direnv reload' Enter
    '';
  };
}
