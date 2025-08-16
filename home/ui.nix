{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../modules/stylix.nix
    ./hyprland.nix
    ./waybar.nix
  ];

  stylix.cursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 3;
  };

  modules.stylix = {
    enable = true;
    autoEnable = true;
    theme = "gruvbox-dark-medium";
  };

  programs.wofi = {
    enable = true;
  };

  programs.ripgrep = {
    enable = true;
  };

  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        disable_loading_bar = true;
        immediate_render = true;
        hide_cursor = false;
      };
      image = [
        {
          position = "-156.5, -470";
          size = "50";
          rounding = -1;
          zindex = 3;
        }
      ];
    };
  };

  programs = {
    kitty = {
      enable = true;
      settings = {
        hide_window_decorations = "yes";
        titlebar_style = "none";
        window_border_width = 0;
        draw_minimal_borders = "yes";
        placement_strategy = "top-right";
        tab_bar_style = "hidden";
        window_padding_width = 0;
        window_margin_width = 0;
      };
    };
    alacritty.enable = true;
  };

  home.packages = with pkgs; [
    networkmanagerapplet
  ];
  stylix.targets.waybar = {
    addCss = true;
  };
}
