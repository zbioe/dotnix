{
  config,
  username,
  stateVersion,
  ...
}:

{
  imports = [
    ./ui
    ./tools.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";

  home.sessionPath = [
    "${config.home.homeDirectory}/.config/emacs/bin"
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.homeDirectory}/.emacs.d/bin"
    "${config.home.homeDirectory}/bin"
    "${config.home.homeDirectory}/go/bin"
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
    GOPATH = "${config.home.homeDirectory}/go";
    GOBIN = "${config.home.homeDirectory}/go/bin";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager = {
    enable = true;
  };

  home.sessionVariablesExtra = ''
    if [ -f "${config.home.homeDirectory}/.env" ]; then
      set -a
      source "${config.home.homeDirectory}/.env"
      set +a
    fi
  '';

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = stateVersion; # Please read the comment before changing.
}
