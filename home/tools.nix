{
  lib,
  ...
}:
{
  services = {
    emacs = {
      enable = false;
      client = {
        enable = false;
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
        "e" = "$EDITOR";
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
    fuzzel = {
      enable = true;
    };
    eza = {
      enable = true;
      enableFishIntegration = true;
      enableBashIntegration = true;
      icons = "auto";
      git = true;
      extraOptions = [
        "--group-directories-first"
      ];
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
}
