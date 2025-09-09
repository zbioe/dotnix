{
  config,
  lib,
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

  services = {
    emacs = {
      enable = true;
      client = {
        enable = true;
      };
    };
  };

  programs = {
    emacs = {
      enable = true;
    };
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    autojump = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
    };
    bash = {
      enable = true;
      historySize = -1;
    };
    zsh = {
      enable = true;
    };
    fish = {
      enable = true;
      shellAbbrs = {
        "hc" = "herbstclient";
      };
      shellInit = ''
        set fish_greeting
        set extraConfig ~/.config/fish/extraConfig.fish
        [ -f $extraConfig ] && source $extraConfig
      '';
    };
    nushell = {
      enable = true;
    };
    fzf = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
    };
    ripgrep = {
      enable = true;
    };
    starship = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      enableZshIntegration = true;
      enableNushellIntegration = true;
      settings = {
        format = lib.concatStrings [
          "$username"
          "$hostname"
          "$directory"
          "$git_branch"
          "$git_commit"
          "$git_metrics"
          "$git_status"
          "$nix_shell"
          "$shell"
          "$memory_usage"
          "$cmd_duration"
          "$line_break"
          "$jobs"
          "$battery"
          "$time"
          "$status"
          "$character"
        ];
        character = {
          error_symbol = "[≻](bold red)";
          success_symbol = "[≻](bold cyan)";
        };
        memory_usage = {
          disabled = false;
        };
        nix_shell = {
          disabled = false;
          format = "[$symbol $state( ($name))]($style) ";
          impure_msg = "[nix](bold yellow)";
          pure_msg = "[nix](bold green)";
          style = "bold blue";
          symbol = "❄";
        };
        shell = {
          disabled = false;
          format = "[λ](dimmed bold blue)[ $indicator]($style) ";
          style = "bold bright-blue";
        };
      };
    };
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
