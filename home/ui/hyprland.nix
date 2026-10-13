{
  pkgs,
  hyprland,
  lib,
  ...
}:

let
  inherit (import ./session.nix { inherit pkgs; }) terminal toggleMic annotate;

  # window_rule helper
  toWorkspace = workspace: class: {
    match.class = class;
    inherit workspace;
  };
in
{
  home.activation.criaMacrosHyprland = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -f ~/.config/hyprland/priv.lua ]; then
      mkdir -p ~/.config/hyprland
      touch ~/.config/hyprland/priv.lua
    fi
  '';

  xdg.configFile."fcitx5/conf/wayland.conf".text = ''
    Allow Overriding System XKB Settings=False
  '';
  wayland.windowManager = {
    hyprland = {
      enable = true;
      package = hyprland;
      # portals come from NixOS (default/ui.nix), which also has gtk/wlr; a
      # home-manager portal dir would hide those backends (no Settings portal)
      portalPackage = null;
      configType = "lua";
      systemd.enable = false; # DISABLE this integration to UWSM can handle it
      xwayland.enable = true;
      settings = {
        env = map (args: { _args = args; }) [
          [
            "XDG_CURRENT_DESKTOP"
            "Hyprland"
          ]
          [
            "XDG_SESSION_TYPE"
            "wayland"
          ]
          [
            "XDG_SESSION_DESKTOP"
            "Hyprland"
          ]
        ];

        config = {
          misc = {
            disable_hyprland_logo = true;
            force_default_wallpaper = 0;
            vrr = 1;
          };

          render = {
            direct_scanout = 1;
          };

          general = {
            gaps_in = 0;
            gaps_out = 0;
            border_size = 0;
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
            enabled = false;
          };

          decoration = {
            rounding = 0;
          };

          input = {
            follow_mouse = 2;
            sensitivity = 0;
            accel_profile = "adaptive";
            kb_layout = "us";
            kb_model = "";
            kb_variant = "intl";
          };
        };

        device = [
          {
            name = "kanata-internal";
            kb_layout = "br";
            kb_variant = "thinkpad";
          }
          {
            name = "kanata-external";
            kb_layout = "us";
            kb_variant = "intl";
          }
        ];

        monitor = [
          {
            output = "";
            mode = "preferred";
            position = "auto-left";
            scale = 1;
          }
          {
            output = "DP-1";
            mode = "1920x1080@180";
            position = "0x0";
            scale = 1;
          }
        ];

        window_rule = [
          (toWorkspace "2" "^(librewolf)$")
          (toWorkspace "3" "^brave-browser$")
          (toWorkspace "5 silent" "^(discord)$")
          (toWorkspace "6" "^(gimp)")
          (toWorkspace "8 silent" "^(workpuls-agent)$")
          (toWorkspace "9" "^(alacritty)$")
          (toWorkspace "9" "^(foot)$")
          (toWorkspace "10" "^(emacs)$")

          # Emacs PGTK prevent popups and context menus to steal the focus
          {
            match = {
              class = "^(emacs)$";
              title = "^$";
            };
            stay_focused = true;
          }

          {
            match.class = "^(org.pulseaudio.pavucontrol)$";
            float = true;
          }
          {
            match.class = "^(nm-connection-editor)$";
            float = true;
          }
          {
            match.class = "^(.blueman-manager-wrapped)$";
            float = true;
          }
        ];
      };

      extraConfig = ''
        local mod = "SUPER"
        local terminal = "${terminal}"

        local function exec(cmd)
          return hl.dsp.exec_cmd(cmd)
        end

        hl.on("hyprland.start", function()
          hl.exec_cmd("librewolf", { workspace = "2 silent" })
          hl.exec_cmd(terminal, { workspace = "9 silent" })
          hl.exec_cmd("discord", { workspace = "5 silent" })
          hl.exec_cmd("emacsclient -cn ~/dev/", { workspace = "10 silent" })
        end)

        hl.bind(mod .. " + F", hl.dsp.window.fullscreen())
        hl.bind(mod .. " + SHIFT + B", exec("uwsm app -- librewolf"))
        hl.bind(mod .. " + SHIFT + N", exec("uwsm app -- nautilus"))
        hl.bind(mod .. " + SHIFT + P", exec("uwsm app -- hyprpicker | wl-copy"))
        hl.bind(mod .. " + RETURN", exec(terminal .. " && exit"))
        hl.bind(mod .. " + Y", exec("foot -e yazi"))
        hl.bind(mod .. " + P", exec("uwsm app -- fuzzel"))
        hl.bind(mod .. " + SHIFT + Q", hl.dsp.window.close())
        hl.bind(mod .. " + SHIFT + R", exec("uwsm app -- hyprlock"))
        hl.bind(mod .. " + SHIFT + X", hl.dsp.exit())

        hl.bind("Print", exec("uwsm app -- grimblast copy area"))
        hl.bind("SHIFT + Print", exec([[uwsm app -- bash -c 'AREA=$(slurp) && sleep 2 && grim -g "$AREA" - | wl-copy']]))
        hl.bind(mod .. " + SHIFT + Y", exec("uwsm app -- grimblast save area - | tesseract stdin stdout | wl-copy"))
        hl.bind(mod .. " + Print", exec([[uwsm app -- ${annotate}]]))
        hl.bind(mod .. " + V", exec([[uwsm app -- sh -c 'cliphist list | fuzzel --dmenu | cliphist decode | wl-copy']]))

        hl.bind("XF86AudioRaiseVolume", exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+"))
        hl.bind(mod .. " + SHIFT + O", exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+"))
        hl.bind("XF86AudioLowerVolume", exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-"))
        hl.bind(mod .. " + SHIFT + I", exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-"))
        hl.bind("XF86AudioMute", exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
        hl.bind(mod .. " + SHIFT + M", exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))

        hl.bind("XF86MonBrightnessUp", exec("brightnessctl s +5%"))
        hl.bind("XF86MonBrightnessDown", exec("brightnessctl s 5%-"))
        hl.bind("XF86AudioMicMute", exec("${toggleMic}"))

        hl.bind(mod .. " + W", hl.dsp.focus({ workspace = "previous" }))
        hl.bind(mod .. " + SHIFT + W", hl.dsp.window.move({ workspace = "previous" }))

        for i = 1, 10 do
          local key = i % 10 -- 10 maps to key 0
          hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }))
          hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
        end

        hl.bind(mod .. " + S", hl.dsp.workspace.toggle_special("magic"))
        hl.bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

        for key, direction in pairs({ h = "left", l = "right", k = "up", j = "down" }) do
          hl.bind(mod .. " + " .. key, hl.dsp.focus({ direction = direction }))
          hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = direction }))
        end

        -- private, unversioned config (macros etc.)
        local priv = os.getenv("HOME") .. "/.config/hyprland/priv.lua"
        if io.open(priv) then
          dofile(priv)
        end
      '';
    };
  };
}
