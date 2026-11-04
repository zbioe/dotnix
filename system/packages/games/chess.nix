# Chess: the engines (chix's) and the boards to study on; the
# terminal tools, Emacs and the Lichess token are in home/games/chess
{
  config,
  lib,
  pkgs,
  inputs,
  dotlib,
  ...
}:
let
  cfg = config.dotnix.packages.games.chess;
in
{
  options.dotnix.packages.games.chess =
    dotlib.mkPackages "chess (engines, analysis and database boards)"
    // {
      engines = lib.mkOption {
        type = lib.types.package;
        default = inputs.chix.packages.${pkgs.stdenv.hostPlatform.system}.engines;
        defaultText = lib.literalExpression "inputs.chix.packages.\${system}.engines";
        description = "The UCI engines, one command each; home/games/chess hands them to the tools and the GUIs.";
      };
    };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = dotlib.packagesOf cfg (
      with pkgs;
      [
        cfg.engines # stockfish, lc0, maia-1100..1900, gnuchess
        en-croissant # analysis, opening explorer, repertoire training
        chessx # databases and opening trees
        fastchess # engine against engine matches
      ]
    );
  };
}
