{
  pkgs,
  config,
  lib,
  ...
}:

let
  tag-setup = pkgs.writeShellScript "river-tag-setup" ''
    for i in $(seq 1 9); do
      tags=$((1 << ($i - 1)))
      riverctl map normal Super $i set-focused-tags $tags
      riverctl map normal Super+Shift $i set-view-tags $tags
    done
    riverctl map normal Super 0 set-focused-tags $(( (1 << 32) - 1 ))
    riverctl map normal Super+Shift 0 set-view-tags $(( (1 << 32) - 1 ))
  '';
in
{
  wayland.windowManager.river = {
    enable = true;
    xwayland.enable = true;

    extraConfig = ''
      # --- UWSM & Autostart ---
      # no "systemctl import-environment" here: UWSM already did it before River started.

      # 'uwsm app --' runs background processes
      # in their own systemd scopes, with logs and a clean cleanup.
      riverctl spawn "uwsm app -- ${pkgs.awww}/bin/awww-daemon"
      riverctl spawn "uwsm app -- ${pkgs.yambar}/bin/yambar"
      riverctl spawn "uwsm app -- ${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
      riverctl spawn "uwsm app -- ${pkgs.mako}/bin/mako"

      # --- Layout ---
      riverctl default-layout rivertile
      riverctl spawn "uwsm app -- ${pkgs.river}/bin/rivertile -view-padding 0 -outer-padding 0"
      riverctl send-layout-cmd rivertile "main-ratio 0.5"
      riverctl send-layout-cmd rivertile "main-count 1"
      riverctl send-layout-cmd rivertile "main-location left"

      # --- Input ---
      riverctl set-cursor-warp on-output-change
      riverctl set-repeat 50 300
      riverctl input "pointer-*" accel-profile flat
      riverctl input "pointer-*" pointer-accel 0

      # --- Bindings ('uwsm app --' works here too) ---
      riverctl map normal Super+Shift Q close
      # 'uwsm stop' is the way out of the session
      riverctl map normal Super+Shift X spawn "uwsm stop" 

      riverctl map normal Super Return spawn "uwsm app -- ${pkgs.foot}/bin/foot"
      riverctl map normal Super P spawn "uwsm app -- ${pkgs.tofi}/bin/tofi-drun --drun-launch=true"
      riverctl map normal Super+Shift B spawn "uwsm app -- librewolf"
      riverctl map normal Super+Shift N spawn "uwsm app -- nautilus"

      # Yazi
      riverctl map normal Super Y spawn "uwsm app -- ${pkgs.foot}/bin/foot -e yazi"

      # Focus/movement
      riverctl map normal Super J focus-view next
      riverctl map normal Super K focus-view previous
      riverctl map normal Super+Shift J swap next
      riverctl map normal Super+Shift K swap previous
      riverctl map normal Super H send-layout-cmd rivertile "main-ratio -0.05"
      riverctl map normal Super L send-layout-cmd rivertile "main-ratio +0.05"
      riverctl map normal Super F toggle-fullscreen

      # Tags
      sh ${tag-setup}

      # Media keys
      riverctl map normal None XF86AudioRaiseVolume spawn "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+"
      riverctl map normal None XF86AudioLowerVolume spawn "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-"
      riverctl map normal None XF86AudioMute spawn "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
      riverctl map normal None XF86MonBrightnessUp spawn "brightnessctl s +5%"
      riverctl map normal None XF86MonBrightnessDown spawn "brightnessctl s 5%-"

      # Printscreen
      riverctl map normal None Print spawn "${pkgs.grimblast}/bin/grimblast copy area"

      # --- UWSM FINALIZE ---
      # tells systemd the compositor is ready:
      # must be the last command.
      exec uwsm finalize
    '';
  };
}
