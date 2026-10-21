{
  config,
  lib,
  dotlib,
  ...
}:
let
  cfg = config.dotnix.shell;
in
{
  imports = [
    ./tmux.nix
    ./env.nix
  ];

  options.dotnix.shell = {
    enable = lib.mkEnableOption "the shells and terminal tools";
    fish.enable = dotlib.mkItem cfg "fish";
    bash.enable = dotlib.mkItem cfg "bash";
    zsh.enable = dotlib.mkItem cfg "zsh";
    nushell.enable = dotlib.mkItem cfg "nushell";
    starship.enable = dotlib.mkItem cfg "the starship prompt";
    direnv.enable = dotlib.mkItem cfg "direnv";
    tmux.enable = dotlib.mkItem cfg "tmux";
    cli.enable = dotlib.mkItem cfg "terminal tools (autojump, fzf, ripgrep, eza)";
  };

  config.programs = {
    direnv = {
      enable = cfg.direnv.enable;
      nix-direnv.enable = true;
    };
    autojump = {
      enable = cfg.cli.enable;
      enableBashIntegration = true;
      enableFishIntegration = true;
    };
    bash = {
      enable = cfg.bash.enable;
      historySize = -1;
    };
    zsh = {
      enable = cfg.zsh.enable;
    };
    fish = {
      enable = cfg.fish.enable;
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
      enable = cfg.nushell.enable;
    };
    fzf = {
      enable = cfg.cli.enable;
      enableBashIntegration = true;
      enableFishIntegration = true;
    };
    ripgrep = {
      enable = cfg.cli.enable;
    };
    eza = {
      enable = cfg.cli.enable;
      enableFishIntegration = true;
      enableBashIntegration = true;
      icons = "auto";
      git = true;
      extraOptions = [
        "--group-directories-first"
      ];
    };
    starship = {
      enable = cfg.starship.enable;
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
