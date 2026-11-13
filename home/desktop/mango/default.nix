# Mango session (the login session, see system/desktop). The shell (bar,
# panels, notifications, lock, wallpaper) is noctalia (home/desktop/noctalia).
{
  lib,
  osConfig,
  config,
  pkgs,
  ...
}:
let
  # the default terminal, running a command
  terms = {
    foot = "foot -e";
    alacritty = "alacritty -e";
    ghostty = "ghostty -e";
    kitty = "kitty";
  };
  main = config.dotnix.desktop.terminals.default;
  term = terms.${if main == null then "foot" else main};
  inherit (import ./session.nix { inherit pkgs term; }) terminal toggleMic annotate;
  stateDir = "${config.xdg.stateHome}/theme";

  # Super+W, the focused monitor's own previous tag; Super+Ctrl+W, back to
  # the previous tag (on its monitor). mango's own `view,-1` counts the
  # special (scratch) tag as a tag and lands on it; these remember the
  # previous normal one instead (the IPC never reports the special tag
  # active, so it never gets in), and the special tag stays Super+S only
  prevTag = "$XDG_RUNTIME_DIR/mango-prev-tag";
  tagHistory = pkgs.writeShellScript "mango-tag-history" ''
    # every monitor's tags, and the focused one's: as they are, then on every
    # change (also before there's a monitor, early in the session)
    declare -A cur
    focused=""
    ${mmsg} watch all-monitors |
      ${jq} --unbuffered -r '.monitors[] | "\(.name) \(.active) \([.tags[] | select(.is_active) | .index] | map(tostring) | join("|"))"' |
      while read -r mon active tags; do
        [ -n "$tags" ] || continue
        if [ "''${cur[$mon]:-}" != "$tags" ]; then
          [ -n "''${cur[$mon]:-}" ] && echo "''${cur[$mon]}" > "${prevTag}.$mon"
          cur[$mon]=$tags
        fi
        if [ "$active" = true ] && [ "$tags" != "$focused" ]; then
          [ -n "$focused" ] && echo "$focused" > "${prevTag}"
          focused=$tags
        fi
      done
  '';
  tagBack = pkgs.writeShellScript "mango-tag-back" ''
    prev=$(cat "${prevTag}" 2>/dev/null) || prev=1
    exec ${tagGo} "$prev"
  '';
  monitorBack = pkgs.writeShellScript "mango-monitor-back" ''
    here=$(${mmsg} get all-monitors | ${jq} -r '.monitors[] | select(.active) | .name')
    prev=$(cat "${prevTag}.$here" 2>/dev/null) || exit 0
    exec ${mmsg} dispatch "view,$prev" >/dev/null
  '';
  jq = "${pkgs.jq}/bin/jq";

  # Tags live on a monitor: the one holding the tag's windows, else the one
  # showing it. Super+N goes there and only that monitor switches (the
  # focused one when both or neither have it); Super+Shift+N sends the
  # window there; Super+Shift+A takes the whole tag to the other monitor
  state = ''
    clients=$(${mmsg} get all-clients)
    monitors=$(${mmsg} get all-monitors)
    q() { ${jq} -n -r --argjson c "$clients" --argjson m "$monitors" "$@"; }
    here=$(q '$m.monitors[] | select(.active) | .name')
  '';
  owner = ''
    there=$(q --arg here "$here" --argjson n "$1" '
      def first_or_here: if index($here) then $here else (.[0] // null) end;
      ([$c.clients[] | select((.tags | index($n)) and (.is_scratchpad | not)) | .monitor] | first_or_here)
      // ([$m.monitors[] | select(.active_tags | index($n)) | .name] | first_or_here)
      // $here')
  '';
  tagGo = pkgs.writeShellScript "mango-tag-go" ''
    ${state}
    ${owner}
    if [ "$there" = "$here" ]; then
      exec ${mmsg} dispatch "view,$1" >/dev/null
    fi
    exec ${mmsg} dispatch "viewcrossmon,$1,$there" >/dev/null
  '';
  tagSend = pkgs.writeShellScript "mango-tag-send" ''
    ${state}
    ${owner}
    if [ "$there" = "$here" ]; then
      exec ${mmsg} dispatch "tag,$1" >/dev/null
    fi
    exec ${mmsg} dispatch "tagcrossmon,$1,$there" >/dev/null
  '';
  tagMove = pkgs.writeShellScript "mango-tag-move" ''
    ${state}
    tag=$(q '$m.monitors[] | select(.active) | .active_tags[0]')
    # the next monitor in the list, by name: "next" would turn around once
    # the first window moved the focus over
    other=$(q --arg here "$here" '[$m.monitors[].name] as $ns | $ns[(($ns | index($here)) + 1) % ($ns | length)]')
    [ "$other" != "$here" ] || exit 0
    # what this monitor shows after: a tag with its windows, else one nobody
    # has, else one of the other's that it isn't showing (from the last)
    next=$(q --arg here "$here" --arg other "$other" --argjson t "$tag" '
      def tags(mon): [$c.clients[] | select(.monitor == mon and (.is_scratchpad | not)) | .tags[]] | unique;
      ($m.monitors[] | select(.name == $other) | .active_tags) as $shown
      | (tags($here) - [$t])
        + ([range(1; 11)] - tags($here) - tags($other) - $shown - [$t])
        + (tags($other) - $shown - [$t] | reverse)
      | .[0] // empty')
    ids=$(q -r --arg here "$here" --argjson t "$tag" '
      $c.clients[] | select(.monitor == $here and (.tags | index($t)) and (.is_scratchpad | not)) | .id')
    if [ -n "$next" ]; then
      ${mmsg} dispatch "view,$next" >/dev/null
    fi
    if [ -z "$ids" ]; then
      exec ${mmsg} dispatch "viewcrossmon,$tag,$other" >/dev/null
    fi
    for id in $ids; do
      ${mmsg} dispatch "tagmon,$other,1" "client,$id" >/dev/null
    done
  '';
  # Super+Shift+H/L: swap with the window on that side, or past the
  # monitor's edge, onto the next monitor
  shove = pkgs.writeShellScript "mango-shove" ''
    edge=$(${jq} -n -r --arg dir "$1" --argjson c "$(${mmsg} get focusing-client)" \
      --argjson m "$(${mmsg} get all-monitors)" '
      ($m.monitors[] | select(.active)) as $mon
      | if $c.id == null then "no"
        elif $dir == "left" then (if $c.x <= $mon.x then "yes" else "no" end)
        else (if $c.x + $c.width >= $mon.x + $mon.width then "yes" else "no" end) end')
    if [ "$edge" = yes ]; then
      exec ${mmsg} dispatch "tagmon,$1" >/dev/null
    fi
    exec ${mmsg} dispatch "exchange_client,$1" >/dev/null
  '';
  mmsg = "${config.wayland.windowManager.mango.package}/bin/mmsg";

  # the clipboard typed at your rhythm (Super+M V), with a Cancel button
  typeClipboard = pkgs.writeShellApplication {
    name = "type-clipboard";
    runtimeInputs = with pkgs; [
      wtype
      wl-clipboard
      libnotify
    ];
    text = "exec ${pkgs.python3}/bin/python3 ${./type-clipboard.py} \"$@\"";
  };

  # every bind with what it does: mango's binds and the noctalia "Shortcuts"
  # panel (Super+/, home/desktop/noctalia) both come from this list
  # an org capture over whatever is open, in its own Emacs frame
  capture = pkgs.writeShellScript "org-capture" ''
    exec emacsclient -c -F '((name . "capture"))' -e '(zmacs/capture-frame)'
  '';

  keys =
    let
      k = group: key: action: desc: {
        inherit
          group
          key
          action
          desc
          ;
      };
    in
    [
      (k "Apps" "SUPER,Return" "spawn_shell,${terminal}" "Terminal (with tmux)")
      (k "Apps" "SUPER,p" "spawn,noctalia msg panel-toggle launcher" "App launcher (noctalia)")
      (k "Apps" "SUPER+SHIFT,b" "spawn,uwsm app -- librewolf" "Browser (LibreWolf)")
      (k "Apps" "SUPER+ALT,n" "spawn,uwsm app -- nautilus" "Files (Nautilus)")
      (k "Apps" "SUPER,y" "spawn,${term} yazi" "Files in the terminal (yazi)")
      (k "Apps" "SUPER,c" "spawn,${capture}" "Capture a task, note or link (org)")
      (k "Apps" "SUPER+SHIFT,p" "spawn_shell,hyprpicker | wl-copy"
        "Color picker: copy a color from the screen"
      )

      (k "System" "SUPER,slash" "spawn,noctalia msg panel-toggle dotnix/keys:list" "This shortcut list")
      (k "System" "SUPER,v" "spawn,noctalia msg panel-toggle clipboard" "Clipboard history")
      (k "System" "SUPER,n" "spawn,noctalia msg notification-clear-active"
        "Dismiss the notifications on screen"
      )
      # no IPC for it: opening the history marks it seen
      (k "System" "SUPER+SHIFT,n"
        "spawn_shell,noctalia msg panel-open control-center notifications && noctalia msg panel-close"
        "Mark notifications as read (clears the bell's dot)"
      )
      (k "System" "SUPER+CTRL,n" "spawn,noctalia msg notification-dnd-toggle" "Toggle do not disturb")
      (k "System" "SUPER+SHIFT,r" "spawn,noctalia msg session lock" "Lock the screen")
      (k "System" "SUPER+SHIFT,u" "spawn,rebuild" "Update the system (rebuild)")
      (k "System" "SUPER,Escape" "spawn,type-clipboard cancel" "Stop typing the clipboard (Super+M V)")
      (k "System" "SUPER+SHIFT,x" "quit" "Quit the session (mango)")

      (k "Screenshot" "NONE,Print" "spawn_shell,grim -g \"$(slurp)\" - | wl-copy" "Area to the clipboard")
      (k "Screenshot" "SHIFT,Print"
        "spawn_shell,AREA=$(slurp) && sleep 2 && grim -g \"$AREA\" - | wl-copy"
        "Area to the clipboard after 2 s"
      )
      (k "Screenshot" "SUPER,Print" "spawn_shell,${annotate}" "Area to annotate (satty)")
      (k "Screenshot" "SUPER+SHIFT,y"
        "spawn_shell,grim -g \"$(slurp)\" - | tesseract stdin stdout | wl-copy"
        "Copy the text in an area (OCR)"
      )

      (k "Audio and brightness" "SUPER+SHIFT,o" "spawn,wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+"
        "Volume up"
      )
      (k "Audio and brightness" "SUPER+SHIFT,i" "spawn,wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-"
        "Volume down"
      )
      (k "Audio and brightness" "SUPER+SHIFT,m" "spawn,wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        "Toggle mute"
      )
      (k "Audio and brightness" "NONE,XF86AudioRaiseVolume"
        "spawn,wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+"
        "Volume up"
      )
      (k "Audio and brightness" "NONE,XF86AudioLowerVolume"
        "spawn,wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-"
        "Volume down"
      )
      (k "Audio and brightness" "NONE,XF86AudioMute" "spawn,wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        "Toggle mute"
      )
      (k "Audio and brightness" "NONE,XF86AudioMicMute" "spawn,${toggleMic}" "Toggle microphone mute")
      # the focused monitor's (the laptop's backlight or DDC/CI); with Shift
      # every monitor's
      (k "Audio and brightness" "NONE,XF86MonBrightnessUp" "spawn,noctalia msg brightness-up"
        "Brightness up (focused monitor)"
      )
      (k "Audio and brightness" "NONE,XF86MonBrightnessDown" "spawn,noctalia msg brightness-down"
        "Brightness down (focused monitor)"
      )
      (k "Audio and brightness" "SHIFT,XF86MonBrightnessUp" "spawn,noctalia msg brightness-up *"
        "Brightness up (every monitor)"
      )
      (k "Audio and brightness" "SHIFT,XF86MonBrightnessDown" "spawn,noctalia msg brightness-down *"
        "Brightness down (every monitor)"
      )

      (k "Windows" "SUPER,h" "focusdir,left" "Focus the window on the left")
      (k "Windows" "SUPER,l" "focusdir,right" "Focus the window on the right")
      (k "Windows" "SUPER,k" "focusdir,up" "Focus the window above")
      (k "Windows" "SUPER,j" "focusdir,down" "Focus the window below")
      (k "Windows" "SUPER+SHIFT,h" "spawn,${shove} left"
        "Swap with the window on the left (at the edge: to the monitor there)"
      )
      (k "Windows" "SUPER+SHIFT,l" "spawn,${shove} right"
        "Swap with the window on the right (at the edge: to the monitor there)"
      )
      (k "Windows" "SUPER+SHIFT,k" "exchange_client,up" "Swap with the window above")
      (k "Windows" "SUPER+SHIFT,j" "exchange_client,down" "Swap with the window below")
      (k "Monitors" "SUPER,a" "focusmon,next" "Focus the other monitor")
      (k "Monitors" "SUPER+SHIFT,a" "spawn,${tagMove}"
        "Take the tag (all its windows) to the other monitor"
      )
      (k "Windows" "SUPER,f" "togglefullscreen" "Fullscreen")
      (k "Windows" "SUPER+SHIFT,q" "killclient" "Close the window")
      (k "Windows" "SUPER,minus" "minimized" "Minimize (hide) the window")
      (k "Windows" "SUPER+SHIFT,minus" "restore_minimized" "Bring back a minimized window, one per press")

      (k "Tags" "SUPER+CTRL,w" "spawn,${tagBack}" "Back to the previous tag (never the special one)")
      (k "Tags" "SUPER,w" "spawn,${monitorBack}" "Back to this monitor's previous tag")
      (k "Tags" "SUPER,s" "toggle_special_tag" "Show/hide the special (scratch) tag")
      (k "Tags" "SUPER+SHIFT,s" "tag_special_tag" "Move the window to the special tag")
    ]
    ++ builtins.concatMap (
      n:
      let
        key = toString (if n == 10 then 0 else n);
      in
      [
        (k "Tags" "SUPER,${key}" "spawn,${tagGo} ${toString n}" "Go to tag ${toString n} (on its monitor)")
        (k "Tags" "SUPER+SHIFT,${key}" "spawn,${tagSend} ${toString n}"
          "Move the window to tag ${toString n} (on its monitor)"
        )
      ]
    ) (builtins.genList (i: i + 1) 10);

  # window_rule helper: open windows of an app_id on a tag
  onTag =
    tag: appId: extra:
    "tags:${toString tag},${extra}app_id:${appId}";
in
{
  options.dotnix.desktop.mango.enable = lib.mkEnableOption "the mango session" // {
    default = osConfig.dotnix.desktop.mango.enable;
  };

  config = lib.mkIf config.dotnix.desktop.mango.enable {
    home.packages = [ typeClipboard ];

    wayland.windowManager.mango = {
      enable = true;
      systemd.enable = false; # uwsm handles the session (system/desktop)

      topPrefixes = [ "source" ];

      settings = {
        # active theme colors (borders etc.), see home/theme
        source = "${stateDir}/current/mango.conf";

        tag_num = 10; # Super+0 is tag 10

        # look: flat, no gaps, borders, rounding or effects
        animations = 0;
        border_px = 0;
        border_radius = 0;
        gap_inner_horizontal = 0;
        gap_inner_vertical = 0;
        gap_outer_horizontal = 0;
        gap_outer_vertical = 0;
        blur = 0;
        shadows = 0;

        # master-stack, new windows go to the stack
        tag_rule = "id:*,layout_name:tile";
        new_is_master = 0;
        default_master_factor = 0.5;

        # testing, 2026-11-12: the laptop panel flickers faintly on some
        # pages; the cursor drawn by the renderer instead of its own plane
        env = [ "WLR_NO_HARDWARE_CURSORS,1" ];

        sloppy_focus = 0;
        # Super+h/l and Super+Shift+h/l go on to the next monitor's windows
        focus_cross_monitor = 1;
        exchange_cross_monitor = 1;
        cursor_size = config.home.pointerCursor.size;
        cursor_theme = config.home.pointerCursor.name;

        xkb_rules_layout = "us";
        xkb_rules_variant = "intl";
        device_rule = [
          "name:kanata-internal,kb_layout:br,kb_variant:thinkpad"
          "name:kanata-external,kb_layout:us,kb_variant:intl"
        ];

        # monitors: arranged in the "Monitors" window and kept by shikane
        # (home/desktop/displays.nix), not fixed here

        window_rule = [
          (onTag 2 "^librewolf$" "")
          (onTag 3 "^brave-browser$" "")
          (onTag 5 "^discord$" "is_open_silent:1,")
          (onTag 6 "^gimp" "")
          (onTag 9 "^(alacritty|foot)$" "")
          # every Emacs frame but the capture one (zmacs/capture-frame)
          "tags:10,app_id:^emacs$,title:^(?!capture$)"
          "is_floating:1,width:900,height:520,app_id:^emacs$,title:^capture$"
          "is_floating:1,app_id:^org.pulseaudio.pavucontrol$"
          "is_floating:1,app_id:^nm-connection-editor$"
          "is_floating:1,app_id:^.blueman-manager-wrapped$"
          # `rebuild` (home/desktop/rebuild.nix): over whatever is open
          "is_floating:1,width:1100,height:700,app_id:^dotnix-rebuild$"
          # its password prompt and log window (zenity)
          "is_floating:1,app_id:^(org\\.gnome\\.)?[Zz]enity$"
          # the browsers' "<site> is sharing your screen" bar (no app_id): its
          # Hide button asks to be minimized, which mango ignores unless allowed
          # per window
          "ignore_minimize:0,title:(is sharing|está compartilhando) (your screen|a window|this tab|sua tela|uma janela|esta guia)"
        ];

        exec_once = [
          "uwsm app -- noctalia"
          "uwsm app -- librewolf"
          terminal
          "uwsm app -- discord"
          "emacsclient -cn ~/dev/"
        ];

        bind = map (k: "${k.key},${k.action}") keys;
      };

      # private, unversioned binds (macros keymode etc.); must stay last: it
      # switches key_mode, and anything after it would land in that mode
      extraConfig = ''
        source_optional=${config.xdg.configHome}/mango/priv.conf
      '';
    };

    # read by the noctalia "Shortcuts" panel (home/desktop/noctalia)
    xdg.configFile."mango/keys.json".source = (pkgs.formats.json { }).generate "keys.json" (
      map (k: { inherit (k) group key desc; }) keys
      ++ [
        {
          group = "System";
          key = "SUPER,m";
          desc = "Macro mode (private binds in ~/.config/mango/priv.conf; Esc leaves)";
        }
      ]
      # tmux's (home/shell/tmux.nix), PREFIX being C-q
      ++ lib.optionals config.dotnix.shell.tmux.enable config.dotnix.shell.tmux.keys
    );

    # the tag history of Super+W, for the whole session (restarted if mango's
    # IPC drops, e.g. after a config reload)
    systemd.user.services.mango-tag-history = {
      Unit = {
        Description = "Previous normal tag for Super+W (mango)";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${tagHistory}";
        Restart = "always";
        RestartSec = 2;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    dotnix.desktop.noctalia.plugins.keys = {
      src = ./plugin;
      manifest = {
        name = "Shortcuts";
        icon = "keyboard";
        description = "Every mango bind with what it does.";
        panel = [
          {
            id = "list";
            entry = "list.luau";
            width = 560;
            height = 720;
            placement = "attached";
            position = "auto";
          }
        ];
      };
      files."keys.json" = config.xdg.configFile."mango/keys.json".source;
    };
  };
}
