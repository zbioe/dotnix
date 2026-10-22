{
  config,
  username,
  stateVersion,
  ...
}:

{
  imports = [
    ./secrets.nix
    ./shell
    ./editors
    ./desktop
    ./theme
    ./dev
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";

  home.sessionPath = [
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.homeDirectory}/bin"
    "${config.home.homeDirectory}/go/bin"
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
    GOPATH = "${config.home.homeDirectory}/go";
    GOBIN = "${config.home.homeDirectory}/go/bin";
  };

  programs.home-manager.enable = true;

  # the desktop and its parts follow the host's choices (osConfig)
  dotnix = {
    theme.enable = true;
    shell = {
      fish.enable = true;
      bash.enable = true;
      zsh.enable = true;
      nushell.enable = true;
      starship.enable = true;
      direnv.enable = true;
      tmux.enable = true;
      cli.enable = true;
    };
    editors.emacs.enable = true;
    dev = {
      node.enable = true;
      opencode.enable = true;
      aiMemory.enable = true;
    };
    desktop = {
      terminals = {
        foot.enable = true;
        alacritty.enable = true;
        ghostty.enable = true;
        kitty.enable = true;
        default = "foot";
      };
      noctalia.enable = true;
      vpn = {
        enable = true;
        favorites = [
          "fastest"
          "BR"
          "US"
          "securecore"
        ];
      };
      wifi.enable = true;
      pass.enable = true;
      rebuild.enable = true;
      insightful.enable = true;
    };
  };

  # the release the home was first made with; do not change
  home.stateVersion = stateVersion;
}
