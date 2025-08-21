{
  config,
  lib,
  pkgs,
  hyprland,
  input_model,
  input_variant,
  ...
}:

{
  wayland.windowManager = {
    hyprland = {
      enable = true;
      package = hyprland;
      xwayland.enable = true;
      settings = {
        "$mod" = "SUPER";

        misc = {
          disable_hyprland_logo = true;
          force_default_wallpaper = 0;
        };

        general = {
          gaps_in = 0;
          gaps_out = 0;
          border_size = 0;
          no_border_on_floating = true;
          layout = "master";
        };

        master = {
          new_on_top = false;
          mfact = 0.5;
        };

        group = {
          groupbar = {
            render_titles = false;
          };
        };

        animations = {
          enabled = "no";
        };
        decoration = {
          rounding = 0;
        };
        windowrulev2 = [
          "noborder, class:.*"
        ];

        input = {
          follow_mouse = 2;
          sensitivity = 0;
          accel_profile = "adaptive";
          kb_options = "caps:ctrl_modifier";
          kb_layout = "br";
          kb_model = input_model;
          kb_variant = input_variant;
        };

        monitor = ",preferred,auto,1";

        bind = [
          "$mod, F, fullscreen,"
          "$mod SHIFT, B, exec, uwsm app -- librewolf"
          "$mod SHIFT, N, exec, uwsm app -- nautilus"
          "$mod SHIFT, P, exec, uwsm app -- hyprpicker"
          "$mod, RETURN, exec, uwsm app -- kitty tmux new-session -A -D -s main && exit"
          "$mod, P, exec, uwsm app -- fuzzel"
          "$mod SHIFT, Q, killactive,"
          "$mod SHIFT, R, exec, uwsm app -- hyprlock"
          "$mod SHIFT, X, exit,"

          ", Print, exec, uwsm app -- grimblast copy area"
          ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+"
          ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-"
          ", XF86XK_AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
          ", XF86MonBrightnessUp, exec, brightnessctl s +5%"
          ", XF86MonBrightnessDown, exec, brightnessctl s 5%-"

          "$mod, w, workspace, previous"
          "$mod SHIFT, w, movetoworkspace, previous"

          "$mod, 1, workspace, 1"
          "$mod, 2, workspace, 2"
          "$mod, 3, workspace, 3"
          "$mod, 4, workspace, 4"
          "$mod, 5, workspace, 5"
          "$mod, 6, workspace, 6"
          "$mod, 7, workspace, 7"
          "$mod, 8, workspace, 8"
          "$mod, 9, workspace, 9"
          "$mod, 0, workspace, 10"

          "$mod SHIFT, 1, movetoworkspace, 1"
          "$mod SHIFT, 2, movetoworkspace, 2"
          "$mod SHIFT, 3, movetoworkspace, 3"
          "$mod SHIFT, 4, movetoworkspace, 4"
          "$mod SHIFT, 5, movetoworkspace, 5"
          "$mod SHIFT, 6, movetoworkspace, 6"
          "$mod SHIFT, 7, movetoworkspace, 7"
          "$mod SHIFT, 8, movetoworkspace, 8"
          "$mod SHIFT, 9, movetoworkspace, 9"
          "$mod SHIFT, 0, movetoworkspace, 10"

          "$mod, S, togglespecialworkspace, magic"
          "$mod SHIFT, S, movetoworkspace, special:magic"

          "$mod, h, movefocus, l"
          "$mod, l, movefocus, r"
          "$mod, k, movefocus, u"
          "$mod, j, movefocus, d"

          "$mod SHIFT, h, movewindow, l"
          "$mod SHIFT, l, movewindow, r"
          "$mod SHIFT, k, movewindow, u"
          "$mod SHIFT, j, movewindow, d"

        ];
      };
    };
  };

}
