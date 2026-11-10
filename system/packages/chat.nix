{
  config,
  lib,
  pkgs,
  unstable,
  dotlib,
  ...
}:
let
  cfg = config.dotnix.packages.chat;
  # Discord's web updates break older Vencord builds (blank window); follow
  # upstream until nixpkgs catches up, then drop this
  vencord = pkgs.vencord.overrideAttrs (
    final: old: {
      version = "1.15.17";
      src = old.src.override {
        tag = "v${final.version}";
        hash = "sha256-+dN4wAFNmYVDiEe0QStqrFBRFHBBRkApqbmhuvsLZZM=";
      };
      # upstream fixed what these worked around (as nixpkgs master does)
      patches = [ ];
      postPatch = "";
      pnpmDeps = old.pnpmDeps.overrideAttrs {
        outputHash = "sha256-/BoLLeKsftWv1bjWuND8967YGhqWEaCZZU6z/oa+0oM=";
      };
    }
  );
in
{
  options.dotnix.packages.chat = dotlib.mkPackages "chat";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = dotlib.packagesOf cfg (
      with pkgs;
      [
        slack # work chat
        telegram-desktop # Telegram
        (discord.override {
          withVencord = true;
          inherit vencord;
        }) # Discord, themed by `theme` through Vencord
        unstable.discordo # Discord in the terminal
        nchat # WhatsApp and Telegram in the terminal
      ]
    );
  };
}
