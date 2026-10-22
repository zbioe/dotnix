# Time from several independent servers, authenticated with NTS (chrony),
# instead of timesyncd's plain NTP that anyone on the path can shift
{ config, lib, ... }:
{
  options.dotnix.core.time.nts.enable = lib.mkEnableOption "authenticated time (NTS)";

  config = lib.mkIf config.dotnix.core.time.nts.enable {
    services.chrony = {
      enable = true;
      enableNTS = true;
      # GrapheneOS's choice: independent operators
      servers = [
        "time.cloudflare.com"
        "nts.netnod.se"
        "ptbtime1.ptb.de"
        "ptbtime2.ptb.de"
      ];
      # its seccomp filter
      extraFlags = [
        "-F"
        "1"
      ];
      extraConfig = ''
        minsources 2
      '';
    };
  };
}
