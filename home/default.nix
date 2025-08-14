{
  config,
  pkgs,
  lib,
  username,
  ...
}:

{
  imports = [
    ./ui.nix
  ];

  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = username;
  home.homeDirectory = "/home/${username}";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "24.05"; # Please read the comment before changing.

  home.sessionPath = [
    "${config.home.homeDirectory}/.config/emacs/bin"
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.homeDirectory}/.emacs.d/bin"
  ];

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [
    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    # pkgs.hello

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/zbioe/etc/profile.d/hm-session-vars.sh
  #
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
      extraConfig = "source ~/.cache/starship/init.nu";
    };
    fzf = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
    };
    starship = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      enableNushellIntegration = true;
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

  # Let Home Manager install and manage itself.
  programs.home-manager = {
    enable = true;
  };
}
