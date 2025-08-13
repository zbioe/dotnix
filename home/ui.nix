{
  config,
  lib,
  pkgs,
  hyprland,
  hyprland-plugins,
  ...
}:

{
  imports = [
    ../modules/stylix.nix
  ];
  modules.stylix = {
    enable = true;
  };
  home = {
    sessionVariables = {
      WLR_NO_HARDWARE_CURSORS = "1";
      NIXOS_OZONE_WL = "1";
    };
    pointerCursor = {
      gtk.enable = true;
      # x11.enable = true;
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 6;
    };
  };
  # gtk = {
  #   enable = true;

  #   theme = {
  #     package = pkgs.flat-remix-gtk;
  #     name = "Flat-Remix-GTK-Grey-Darkest";
  #   };

  #   iconTheme = {
  #     package = pkgs.gnome.adwaita-icon-theme;
  #     name = "Adwaita";
  #   };

  #   font = {
  #     name = "Sans";
  #     size = 11;
  #   };
  # };

  wayland.windowManager = {
    hyprland = {
      enable = true;
      package = hyprland;
      xwayland.enable = true;
      systemd.variables = [ "--all" ];
      settings = {
        "$mod" = "SUPER";

        misc = {
          disable_hyprland_logo = true;
          force_default_wallpaper = 0;
        };

        bind = [
          "$mod, F, exec, firefox"
          "$mod, RETURN, exec, kitty"
          "$mod, Q, killactive,"
          "$mod, X, exit,"
          ", Print, exec, grimblast copy area"
        ]
        ++ (
          # workspaces
          # binds $mod + [shift +] {1..9} to [move to] workspace {1..9}
          builtins.concatLists (
            builtins.genList (
              i:
              let
                ws = i + 1;
              in
              [
                "$mod, code:1${toString i}, workspace, ${toString ws}"
                "$mod SHIFT, code:1${toString i}, movetoworkspace, ${toString ws}"
              ]
            ) 9
          )
        );
      };
      plugins = [
        hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprbars
      ];
    };
  };
  programs = {
    kitty.enable = true;
    # alacritty.enable = true;
  };
}
