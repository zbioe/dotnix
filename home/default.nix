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
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
  };

   # Let Home Manager install and manage itself.
  programs.home-manager = {
    enable = true;
  };

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = stateVersion; # Please read the comment before changing.
}
