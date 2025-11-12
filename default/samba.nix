{
  config,
  lib,
  pkgs,
  ...
}:

{
  services.samba = {
    enable = true;
    securityType = "user";
    openFirewall = true;
    settings = {
      global = {
        browseable = "yes";
        "smb encrypt" = "required";
      };
      "public" = {
        "path" = "/mnt/Shares/Public";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "0755";
        "valid users" = "zbioe";
      };
    };
  };

  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  networking.firewall.enable = true;
  networking.firewall.allowPing = true;
}
