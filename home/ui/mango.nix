# Mango session (second login entry next to Hyprland, see default/ui.nix).
# Same keys, tags and rules as home/ui/hyprland.nix; the shell (bar, panels,
# notifications, lock, wallpaper) is noctalia (home/ui/noctalia.nix).
{
  config,
  pkgs,
  ...
}:
let
  inherit (import ./session.nix { inherit pkgs; }) terminal toggleMic annotate;
  stateDir = "${config.xdg.stateHome}/theme";

  # every bind with what it does: mango's binds and the noctalia "Shortcuts"
  # panel (Super+/, home/ui/noctalia.nix) both come from this list
  keys =
    let
      k = group: key: action: desc: { inherit group key action desc; };
    in
    [
      (k "Apps" "SUPER,Return" "spawn_shell,${terminal}" "Terminal (foot + tmux)")
      (k "Apps" "SUPER,p" "spawn,noctalia msg panel-toggle launcher" "App launcher (noctalia)")
      (k "Apps" "SUPER+SHIFT,b" "spawn,uwsm app -- librewolf" "Browser (LibreWolf)")
      (k "Apps" "SUPER+SHIFT,n" "spawn,uwsm app -- nautilus" "Files (Nautilus)")
      (k "Apps" "SUPER,y" "spawn,foot -e yazi" "Files in the terminal (yazi)")
      (k "Apps" "SUPER+SHIFT,p" "spawn_shell,hyprpicker | wl-copy" "Color picker: copy a color from the screen")

      (k "System" "SUPER,slash" "spawn,noctalia msg panel-toggle dotnix/keys:list" "This shortcut list")
      (k "System" "SUPER,v" "spawn,noctalia msg panel-toggle clipboard" "Clipboard history")
      (k "System" "SUPER,n" "spawn,noctalia msg notification-clear-active" "Dismiss the notifications on screen")
      # no IPC for it: opening the history marks it seen
      (k "System" "SUPER+ALT,n" "spawn_shell,noctalia msg panel-open control-center notifications && noctalia msg panel-close" "Mark notifications as read (clears the bell's dot)")
      (k "System" "SUPER+CTRL,n" "spawn,noctalia msg notification-dnd-toggle" "Toggle do not disturb")
      (k "System" "SUPER+SHIFT,r" "spawn,noctalia msg session lock" "Lock the screen")
      (k "System" "SUPER+SHIFT,u" "spawn,rebuild" "Update the system (rebuild)")
      (k "System" "SUPER+SHIFT,x" "quit" "Quit the session (mango)")

      # grimblast is Hyprland-only: plain grim + slurp
      (k "Screenshot" "NONE,Print" "spawn_shell,grim -g \"$(slurp)\" - | wl-copy" "Area to the clipboard")
      (k "Screenshot" "SHIFT,Print" "spawn_shell,AREA=$(slurp) && sleep 2 && grim -g \"$AREA\" - | wl-copy" "Area to the clipboard after 2 s")
      (k "Screenshot" "SUPER,Print" "spawn_shell,${annotate}" "Area to annotate (satty)")
      (k "Screenshot" "SUPER+SHIFT,y" "spawn_shell,grim -g \"$(slurp)\" - | tesseract stdin stdout | wl-copy" "Copy the text in an area (OCR)")

      (k "Audio and brightness" "SUPER+SHIFT,o" "spawn,wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+" "Volume up")
      (k "Audio and brightness" "SUPER+SHIFT,i" "spawn,wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-" "Volume down")
      (k "Audio and brightness" "SUPER+SHIFT,m" "spawn,wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" "Toggle mute")
      (k "Audio and brightness" "NONE,XF86AudioRaiseVolume" "spawn,wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+" "Volume up")
      (k "Audio and brightness" "NONE,XF86AudioLowerVolume" "spawn,wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-" "Volume down")
      (k "Audio and brightness" "NONE,XF86AudioMute" "spawn,wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" "Toggle mute")
      (k "Audio and brightness" "NONE,XF86AudioMicMute" "spawn,${toggleMic}" "Toggle microphone mute")
      (k "Audio and brightness" "NONE,XF86MonBrightnessUp" "spawn,brightnessctl s +5%" "Brightness up")
      (k "Audio and brightness" "NONE,XF86MonBrightnessDown" "spawn,brightnessctl s 5%-" "Brightness down")

      (k "Windows" "SUPER,h" "focusdir,left" "Focus the window on the left")
      (k "Windows" "SUPER,l" "focusdir,right" "Focus the window on the right")
      (k "Windows" "SUPER,k" "focusdir,up" "Focus the window above")
      (k "Windows" "SUPER,j" "focusdir,down" "Focus the window below")
      (k "Windows" "SUPER+SHIFT,h" "exchange_client,left" "Swap with the window on the left")
      (k "Windows" "SUPER+SHIFT,l" "exchange_client,right" "Swap with the window on the right")
      (k "Windows" "SUPER+SHIFT,k" "exchange_client,up" "Swap with the window above")
      (k "Windows" "SUPER+SHIFT,j" "exchange_client,down" "Swap with the window below")
      (k "Windows" "SUPER,f" "togglefullscreen" "Fullscreen")
      (k "Windows" "SUPER+SHIFT,q" "killclient" "Close the window")
      (k "Windows" "SUPER,minus" "minimized" "Minimize (hide) the window")
      (k "Windows" "SUPER+SHIFT,minus" "restore_minimized" "Bring back a minimized window, one per press")

      (k "Tags" "SUPER,w" "view,-1" "Back to the previous tag")
      (k "Tags" "SUPER,s" "toggle_special_tag" "Show/hide the special (scratch) tag")
      (k "Tags" "SUPER+SHIFT,s" "tag_special_tag" "Move the window to the special tag")
    ]
    ++ builtins.concatMap (
      n:
      let
        key = toString (if n == 10 then 0 else n);
      in
      [
        (k "Tags" "SUPER,${key}" "view,${toString n}" "Go to tag ${toString n}")
        (k "Tags" "SUPER+SHIFT,${key}" "tag,${toString n}" "Move the window to tag ${toString n}")
      ]
    ) (builtins.genList (i: i + 1) 10);

  # window_rule helper: open windows of an app_id on a tag
  onTag =
    tag: appId: extra:
    "tags:${toString tag},${extra}app_id:${appId}";
in
{
  wayland.windowManager.mango = {
    enable = true;
    systemd.enable = false; # uwsm handles the session (default/ui.nix)

    topPrefixes = [ "source" ];

    settings = {
      # active theme colors (borders etc.), see home/theme
      source = "${stateDir}/current/mango.conf";

      tag_num = 10; # Super+0 is tag 10, like Hyprland's workspace 10

      # look: same as the Hyprland session
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

      sloppy_focus = 0;
      cursor_size = config.stylix.cursor.size;
      cursor_theme = config.stylix.cursor.name;

      xkb_rules_layout = "us";
      xkb_rules_variant = "intl";
      device_rule = [
        "name:kanata-internal,kb_layout:br,kb_variant:thinkpad"
        "name:kanata-external,kb_layout:us,kb_variant:intl"
      ];

      monitor_rule = "name:DP-1,width:1920,height:1080,refresh:180,x:0,y:0,scale:1";

      window_rule = [
        (onTag 2 "^librewolf$" "")
        (onTag 3 "^brave-browser$" "")
        (onTag 5 "^discord$" "is_open_silent:1,")
        (onTag 6 "^gimp" "")
        (onTag 8 "^workpuls-agent$" "is_open_silent:1,")
        (onTag 9 "^(alacritty|foot)$" "")
        (onTag 10 "^emacs$" "")
        "is_floating:1,app_id:^org.pulseaudio.pavucontrol$"
        "is_floating:1,app_id:^nm-connection-editor$"
        "is_floating:1,app_id:^.blueman-manager-wrapped$"
        # `rebuild` (home/ui/rebuild.nix): over whatever is open
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

  # read by the noctalia "Shortcuts" panel (home/ui/noctalia.nix)
  xdg.configFile."mango/keys.json".source = (pkgs.formats.json { }).generate "keys.json" (
    map (k: { inherit (k) group key desc; }) keys
    ++ [
      {
        group = "System";
        key = "SUPER,m";
        desc = "Macro mode (private binds in ~/.config/mango/priv.conf; Esc leaves)";
      }
    ]
  );
}
