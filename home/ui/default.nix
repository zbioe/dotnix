{
  lib,
  pkgs,
  unstable,
  ...
}:
{
  imports = [
    ../../modules/stylix.nix
    ./hyprland.nix
    ./waybar.nix
    # ./river.nix
    # ./yambar.nix
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
    bat = {
      enable = true;
    };
    foot = {
      enable = true;
      server.enable = true;
      settings = {
        main = {
          term = "xterm-256color";
        };
      };
    };
    alacritty = {
      enable = true;
      package = unstable.alacritty;
    };
    ghostty = {
      enable = true;
      package = unstable.ghostty;
      systemd.enable = true;
      installVimSyntax = true;
      installBatSyntax = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
    };
    kitty = {
      enable = true;
      package = unstable.kitty;
      settings = {
        hide_window_decorations = "yes";
        titlebar_style = "none";
        window_border_width = 0;
        draw_minimal_borders = "no";
        placement_strategy = "top-right";
        tab_bar_style = "hidden";
        window_padding_width = 0;
        window_margin_width = 0;
        font_size = 10.26;
      };
    };
    tofi = {
      enable = true;
      settings = {
        width = "100%";
        height = "100%";
        border-width = 0;
        outline-width = 0;
        padding-left = "35%";
        padding-top = "35%";
        result-spacing = 25;
        num-results = 5;
        background-color = lib.mkForce "#00000080";
      };
    };
    yazi = {
      enable = true;
      enableFishIntegration = true;
    };
  };

  home.packages = with pkgs; [
    libnotify
    networkmanagerapplet
    wirelesstools
    brightnessctl
    wl-clipboard
    grimblast
    hyprpicker
    nautilus
  ];

}
