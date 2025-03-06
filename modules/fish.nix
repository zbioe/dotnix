{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) types mkOption mkIf;
  cfg = config.modules.fish;
in
{
  options.modules.fish = with types; {
    enable = mkOption {
      type = bool;
      default = false;
      description = ''
        Enable fish shell with starship personalization.
      '';
    };
  };

  config = mkIf cfg.enable {
    modules.user = {
      shell = pkgs.fish;
    };
    programs.fish = {
      enable = true;
      shellAbbrs = {
        "n" = "nvim";
      };
      shellInit = ''
        set fish_greeting
        test -f ~/.secrets.fish && source ~/.secrets.fish
      '';
    };
    programs.starship = {
      enable = true;
      settings = {
        add_newline = true;
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
