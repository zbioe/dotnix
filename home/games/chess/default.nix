# Chess: chix (github:zbioe/chix) with this host's engines, your users and
# the Lichess token; launchers in the default terminal and browser. Emacs'
# packages are zmacs' (lisp/chess.el)
{
  config,
  lib,
  osConfig,
  ...
}:
let
  cfg = config.dotnix.games.chess;
  secrets = ../../../secrets/chess.yaml;
in
{
  options.dotnix.games.chess = {
    enable = lib.mkEnableOption "chix: openings, your games reviewed, training and puzzles" // {
      default = osConfig.dotnix.packages.games.chess.enable;
    };
    lichess.enable = lib.mkEnableOption ''
      the Lichess token, `lichess-token` in secrets/chess.yaml: playing from
      chess-tui and Emacs, the opening explorer, puzzles on your account'';
    lichess.user = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Your Lichess user: your games in `chess`.";
    };
    chesscom.user = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Your chess.com user: your games in `chess`.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        programs.chix = {
          enable = true;
          lichess.user = cfg.lichess.user;
          chesscom.user = cfg.chesscom.user;
          # the system has them (system/packages/games/chess.nix); its
          # profile's paths survive rebuilds
          engines = {
            package = osConfig.dotnix.packages.games.chess.engines;
            install = false;
            binDir = "/run/current-system/sw/bin";
            seedGuis = true;
          };
          desktop = {
            terminal = lib.mapNullable (
              t:
              {
                foot = "foot";
                alacritty = "alacritty -e";
                ghostty = "ghostty -e";
                kitty = "kitty";
              }
              .${t}
            ) config.dotnix.desktop.terminals.default;
            webApp = lib.mapNullable (
              b:
              {
                brave = "brave --app=";
                chromium = "chromium --app=";
                librewolf = "librewolf --new-window ";
              }
              .${b}
            ) osConfig.dotnix.desktop.browsers.default;
          };
        };
      }

      (lib.mkIf cfg.lichess.enable {
        assertions = [
          {
            assertion = builtins.pathExists secrets;
            message = "dotnix.games.chess.lichess needs secrets/chess.yaml (sops secrets/chess.yaml, key lichess-token)";
          }
        ];
        sops.secrets.lichess-token.sopsFile = secrets;
        programs.chix.lichess.tokenFile = config.sops.secrets.lichess-token.path;
        # lichess.el reads it with auth-source
        sops.templates.authinfo = {
          path = "${config.home.homeDirectory}/.authinfo";
          content = ''
            machine lichess.org login lichess password ${config.sops.placeholder.lichess-token}
          '';
        };
      })
    ]
  );
}
