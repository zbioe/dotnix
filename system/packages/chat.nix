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
in
{
  options.dotnix.packages.chat = dotlib.mkPackages "chat";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = dotlib.packagesOf cfg (
      with pkgs;
      [
        slack # work chat
        telegram-desktop # Telegram
        (discord.override { withVencord = true; }) # Discord, themed by `theme` through Vencord
        unstable.discordo # Discord in the terminal
        nchat # WhatsApp and Telegram in the terminal
      ]
    );
  };
}
