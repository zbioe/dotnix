{
  config,
  lib,
  pkgs,
  ...
}:
let
  # the binds worth remembering, for prefix ? (below) and the Super+/
  # shortcuts panel (home/desktop/mango): "MODS,key" like mango's, PREFIX
  # being C-q
  k = group: key: desc: { inherit group key desc; };
  keys = [
    (k "tmux" "PREFIX,c" "New window (in the pane's folder)")
    (k "tmux" "PREFIX,h" "Split side by side")
    (k "tmux" "PREFIX,v" "Split one above the other")
    (k "tmux" "PREFIX+CTRL,b" "Pane on the left (C-n down, C-p up, C-f right)")
    (k "tmux" "PREFIX+ALT,b" "Resize the pane (M-b/n/p/f)")
    (k "tmux" "PREFIX,a" "Last window (also C-a)")
    (k "tmux" "PREFIX,k" "Close the window (K: without asking)")
    (k "tmux" "PREFIX,j" "Close the pane (J: without asking)")
    (k "tmux" "PREFIX,s" "Pick a session or window (fzf)")
    (k "tmux" "PREFIX,g" "lazygit, floating")
    (k "tmux" "PREFIX+SHIFT,p" "A shell, floating")
    (k "tmux" "PREFIX+SHIFT,f" "Hints over URLs, paths, hashes: letter copies, capital opens")
    (k "tmux" "PREFIX,y" "Copy the last command's output")
    (k "tmux" "PREFIX,w" "Copy tmux's buffer to the clipboard")
    (k "tmux" "PREFIX+CTRL,y" "Paste tmux's buffer")
    (k "tmux" "PREFIX+SHIFT,s" "Type into every pane of the window (on/off)")
    (k "tmux" "PREFIX,m" "Mark the pane (@ brings it into this window)")
    (k "tmux" "PREFIX+CTRL,s" "Save the sessions (also every 15 min)")
    (k "tmux" "PREFIX+SHIFT,r" "Restore the saved sessions")
    (k "tmux" "PREFIX,e" "This folder as the session's default")
    (k "tmux" "PREFIX,r" "Reload the config")
    (k "tmux" "PREFIX+CTRL,r" "direnv reload in the pane")
    (k "tmux" "PREFIX,?" "This list")
    (k "tmux copy mode" "PREFIX+CTRL,[" "Enter copy mode (or the mouse wheel)")
    (k "tmux copy mode" "CTRL,e" "Scroll a line down (C-y up)")
    (k "tmux copy mode" "CTRL,d" "Half a page down (C-u up)")
    (k "tmux copy mode" "CTRL,v" "A page down (M-v up)")
    (k "tmux copy mode" ",[" "Previous command's output (] next; M-p, M-n)")
    (k "tmux copy mode" ",g g" "Top (G bottom, :N line N)")
    (k "tmux copy mode" ",/" "Search down (? up; C-s, C-r; n, N again)")
    (k "tmux copy mode" ",v" "Select (V the line, C-Space too; R rectangle)")
    (k "tmux copy mode" ",y" "Copy to the clipboard (Y to the line's end; M-w)")
    (k "tmux copy mode" ",Escape" "Drop the selection, or leave (q, i)")
    (k "tmux copy mode" ",h" "Move: h j k l, w b e, 0 ^ $, H M L, { } %; and C-n/p/f/b")
  ];
  # the same as tmux writes binds: C-q S, C-q C-s, C-e
  tmuxKey =
    key:
    let
      parts = lib.splitString "," key;
      mods = lib.filter (m: m != "") (lib.splitString "+" (lib.head parts));
      base = lib.concatStringsSep "," (lib.tail parts);
      has = m: lib.elem m mods;
      letter = if has "SHIFT" then lib.toUpper base else base;
      named = { Escape = "Esc"; }.${letter} or letter;
      chord =
        if has "CTRL" then
          "C-${named}"
        else if has "ALT" then
          "M-${named}"
        else
          named;
    in
    if has "PREFIX" then "C-q ${chord}" else chord;
  pad = n: s: s + lib.concatStrings (lib.genList (_: " ") (n - lib.stringLength s));
  cheatsheet = pkgs.writeText "tmux-keys" (
    lib.concatMapStrings (
      group:
      "${group}\n"
      + lib.concatMapStrings (b: "  ${pad 10 (tmuxKey b.key)}  ${b.desc}\n") (
        lib.filter (b: b.group == group) keys
      )
      + "\n"
    ) (lib.unique (map (b: b.group) keys))
  );

  # the last command's output: from the last output mark down to the prompt
  # under it (starship's: a blank line, its info line and the ≻ line),
  # wrapped lines joined
  copyOutput = pkgs.writeShellScript "tmux-copy-output" ''
    pane=$1
    cy=$(tmux display -p -t "$pane" '#{cursor_y}')
    out=$(tmux capture-pane -p -F -S - -E "$cy" -t "$pane" | ${pkgs.gawk}/bin/awk '
      { i = index($0, " "); f[NR] = substr($0, 1, i - 1); t[NR] = substr($0, i + 1)
        if (f[NR] ~ /O/) start = NR }
      END {
        if (!start) exit 1
        last = NR - 3
        while (last >= start && t[last] ~ /^[[:space:]]*$/) last--
        if (last < start) exit 1
        for (n = start; n <= last; n++)
          printf "%s%s", t[n], (n == last || f[n] ~ /W/) ? "" : "\n"
      }') || { tmux display "no command output here"; exit 0; }
    printf '%s' "$out" | ${pkgs.wl-clipboard}/bin/wl-copy
    tmux display "copied the last output ($(printf '%s\n' "$out" | wc -l) lines)"
  '';
in
{
  options.dotnix.shell.tmux.keys = lib.mkOption {
    type = lib.types.listOf lib.types.attrs;
    readOnly = true;
    default = keys;
    description = "tmux's binds worth remembering, for the shortcuts panel.";
  };

  config.programs.tmux = {
    enable = config.dotnix.shell.tmux.enable;
    sensibleOnTop = false;
    shortcut = "q";
    # inside: tmux's own terminfo; outside, what each terminal can do below
    terminal = "tmux-256color";
    resizeAmount = 8;
    # wheel scrolls (into copy mode), click focuses a pane, drag resizes
    mouse = true;
    plugins = with pkgs.tmuxPlugins; [
      # prefix F: letters over the URLs, paths, hashes and IPs on screen;
      # its letter copies one, the capital letter opens it
      {
        plugin = tmux-thumbs;
        extraConfig = ''
          set -g @thumbs-key F
          set -g @thumbs-command 'echo -n {} | wl-copy && tmux display "copied {}"'
          set -g @thumbs-upcase-command 'xdg-open {} >/dev/null 2>&1 &'
        '';
      }
      # prefix C-s saves the sessions (windows, panes, folders), prefix R
      # brings them back after a reboot; never by itself, start-tmux.sh
      # makes the usual ones
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-save 'C-s'
          set -g @resurrect-restore 'R'
        '';
      }
      # and saves them every 15 minutes (last: it hooks the status line)
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-save-interval '15'
          set -g @continuum-restore 'off'
        '';
      }
    ];
    extraConfig = ''
      set-option -g set-titles on
      set-option -g set-titles-string "Tmux - #S #T"
      setw -g automatic-rename-format "#{b:pane_current_path}"
      set-option -sg escape-time 10
      set-option -g focus-events on

      # 24-bit color, images and the clipboard through the outer terminal
      set -as terminal-features 'foot*:RGB:sixel:clipboard:extkeys:usstyle:hyperlinks'
      set -as terminal-features 'alacritty*:RGB:sixel:clipboard:usstyle:hyperlinks'
      set -as terminal-features 'xterm-kitty:RGB:clipboard:usstyle:hyperlinks'
      set -as terminal-features 'xterm-ghostty:RGB:clipboard:usstyle:hyperlinks'
      set -g allow-passthrough on

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

      # floating windows over the panes, in the pane's folder: lazygit, a
      # shell; prefix s picks a session or window with fzf
      bind g display-popup -E -w 90% -h 90% -d "#{pane_current_path}" lazygit
      bind P display-popup -E -w 80% -h 80% -d "#{pane_current_path}"
      bind s display-popup -E -w 60% -h 60% "tmux list-windows -a -F '#S:#I  #W  #{b:pane_current_path}' | fzf --reverse | cut -d' ' -f1 | xargs -r tmux switch-client -t"

      # prefix S types into every pane of the window at once (on/off); prefix
      # m marks a pane, prefix @ brings the marked one into this window
      bind S setw synchronize-panes \; display "synchronized panes: #{?synchronize-panes,on,off}"
      bind @ join-pane

      # Commands' outputs, as fish marks their start (OSC 133 C; its prompt
      # marks don't survive the prompt's redraw): [ and ] (or M-p, M-n) jump
      # between them in copy mode; prefix y copies the last one
      bind -T copy-mode [ send -X previous-prompt -o
      bind -T copy-mode ] send -X next-prompt -o
      bind -T copy-mode M-p send -X previous-prompt -o
      bind -T copy-mode M-n send -X next-prompt -o
      bind y run-shell "${copyOutput} '#{pane_id}'"

      # the list above (prefix / keeps tmux's own, every bind)
      bind ? display-popup -E -w 90 -h 90% "less -R ${cheatsheet}"
      bind / list-keys -N
    '';
  };
}
