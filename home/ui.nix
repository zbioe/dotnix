{
  pkgs,
  ...
}:
{
  imports = [
    ../modules/stylix.nix
    ./hyprland.nix
    ./waybar.nix
  ];

  stylix = {
    icons = {
      enable = true;
      package = pkgs.papirus-icon-theme;
      dark = "Papirus-Dark";
      light = "Papirus-Light";
    };
    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 3;
    };
  };

  modules.stylix = {
    enable = true;
    autoEnable = true;
    theme = "gruvbox-dark-medium";
    polarity = "dark";
  };

  programs.fuzzel = {
    enable = true;
  };

  programs.ripgrep = {
    enable = true;
  };

  services.mako = {
    enable = true;
    settings = {
      layer = "overlay";
      default-timeout = 5000;
      icons = true;
      border-radius = 15;
    };
  };

  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        disable_loading_bar = true;
        immediate_render = true;
        hide_cursor = true;
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
  };

  home.packages = with pkgs; [
    networkmanagerapplet
  ];

}
