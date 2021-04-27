{ config, lib, pkgs, ... }:

let
  defaultPkgs = with pkgs; [

    # System utils
    file
    mpv
    oguri
    sxhkd
    zathura
    flashfocus
    pavucontrol
    scrcpy
    polybar
    tint2
    font-manager
    rofi
    i3lock-color
    dmenu
    gnome3.nautilus
    sqlite
    xsel
    arandr

    # GTK theme
    numix-icon-theme

    # Compilers, interpreters and build systems
    clang
    glslang
    cmake
    sbcl
    ninja
    meson
    zig
    lua
    sumneko-lua-language-server
    kotlin

    # Terminals, IDEs and Editors
    alacritty
    tmux
    neovim

    # Terminal apps and utils
    go-2fa
    tmux
    bat
    ncdu
    manix
    exa
    _0x0
    unp
    fd
    ripgrep
    irony-server
    rtags
    ktlint
    shellcheck
    imagemagick
    libnotify
    scrot
    maim
    slop
    xdotool
    ffmpeg
    hsetroot
    ranger

    # WM
    maim # screenshot
    translate-shell
    gnome3.zenity # dialog
    xclip
    font-awesome-ttf
    lm_sensors

    # Chat
    tdesktop
    discord
    discocss

    # Music
    playerctl
    spotify
    youtube-dl

    # Web
    google-chrome
    qutebrowser

    # Tools
    krita # image manipulation

    # API
    azure-cli

  ];

in {

  home.username = "zbioe";
  home.homeDirectory = "/home/zbioe";
  home.packages = defaultPkgs;

  imports = (import ./langs) ++ (import ./browsers);

  services = {
    lorri.enable = true;
    flameshot.enable = true;
  };

  programs.bat = {
    enable = true;
    config.theme = "gruvbox-dark";
  };

  programs.git = {
    enable = true;
    userName = "Iury Fukuda";
    userEmail = "zbioe@protonmail.com";
  };

  gtk = {
    enable = true;
    iconTheme = {
      name = "Numix";
      package = pkgs.numix-icon-theme;
    };
    font = { name = "Noto 15"; };
    theme = {
      package = pkgs.gruvbox-dark-gtk;
      name = "gruvbox-dark";
    };
  };

  programs.emacs = { enable = true; };

  services.emacs = {
    enable = true;
    client = {
      enable = true;
      arguments = [ "--no-wait" ];
    };
  };
  # start emacs after graphical session
  systemd.user.services.emacs = {
    Unit.After = [ "graphical-session.target" ];
    Install.WantedBy = lib.mkForce [ "graphical-session.target" ];
  };

  home.sessionPath = [ "${config.home.homeDirectory}/.doom-emacs/bin" ];

  # disabled for now
  services.picom = { enable = true; };

  # Ctrl works as ESC when one time pressed
  services.xcape = {
    enable = true;
    mapExpression = { Control_L = "Escape"; };
  };

  # configure monitors outputs
  services.grobi = {
    enable = true;
    rules = let
      internal = "eDP-1";
      external = "HDMI-1";
    in [
      {
        name = "Two Monitors";
        outputs_connected = [ external ];
        configure_column = [ external internal ];
        primary = external;
        atomic = true;
      }
      {
        name = "One Monitor";
        outputs_disconnected = [ external ];
        configure_single = internal;
        primary = true;
        atomic = true;
      }
    ];
  };

  # services.grobi = {
  #   enable = true;
  #   rules = let
  #     internal = "eDP-1";
  #     external = "HDMI-1";
  #     useAll = name: outputs: {
  #       inherit name;
  #       outputs_connected = outputs;
  #       configure_column = lib.reverseList outputs;
  #       primary = builtins.head outputs;
  #       atomic = false;
  #     };
  #   in [
  #     (useAll "Two screen" [ internal external ])
  #     (useAll "One screen" [ internal ])
  #   ];
  # };

  services.dunst = {
    enable = true;
    iconTheme = {
      name = "Numix";
      package = pkgs.numix-icon-theme;
    };
  };

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;

    enableNixDirenvIntegration = true;
  };

  programs.autojump = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
  };

  # Fast Rust-powered shell prompt.
  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
  };

  # Fast Rust-powered shell prompt.
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
  };

  programs.feh = { enable = true; };

  programs.jq.enable = true;

  programs.home-manager.enable = true;

  home.stateVersion = "21.05";

}
