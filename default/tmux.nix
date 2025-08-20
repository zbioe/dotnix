{
  pkgs,
  ...
}:

{
  programs.tmux = {
    enable = true;
    shortcut = "q";
    terminal = "screen-256color";
    resizeAmount = "8";
    extraConfig = ''
      set-option -g set-titles on
      set-option -g set-titles-string "Tmux - #S #T"
      setw -g automatic-rename-format "#{b:pane_current_path}"

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

      setw -g automatic-rename-format "#{b:pane_current_path}"
      bind e 'attach -c "#{pane_current_path}"; display "default path setted"'
      bind w run "tmux save-buffer - | wl-copy"
      bind r 'source-file ~/.tmux.conf; display "reloaded"'
      bind ^R send-keys 'direnv reload' Enter
    '';
  };
}
