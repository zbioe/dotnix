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
    ./ai.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";

  home.sessionPath = [
    "${config.home.homeDirectory}/.config/emacs/bin"
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.homeDirectory}/.emacs.d/bin"
    "${config.home.homeDirectory}/.emacs.d/bin"
    "${config.home.homeDirectory}/.cache/bun/bin"
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

  # Load ~/.env file in bash and fish
  programs.bash.profileExtra = ''
    if [ -f "$HOME/.env" ]; then
      set -a
      source "$HOME/.env"
      set +a
    fi
  '';

  programs.bash.bashrcExtra = ''
    if [ -f "$HOME/.env" ]; then
      set -a
      source "$HOME/.env"
      set +a
    fi
  '';

  programs.fish.interactiveShellInit = ''
    if test -f "$HOME/.env"
      while read -l line
        # Ignora comentários (#) e linhas vazias
        if not string match -q -r '^\s*#|^\s*$' "$line"
          # Separa no primeiro '='
          set -l kv (string split -m 1 "=" "$line")
          # Exporta limpando aspas caso você tenha colocado no .env
          set -gx $kv[1] (string trim -c '"\''' $kv[2])
        end
      end < "$HOME/.env"
    end
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
