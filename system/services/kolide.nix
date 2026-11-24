{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.dotnix.services.kolide;
in
{
  imports = [ inputs.kolide-launcher.nixosModules.kolide-launcher ];

  options.dotnix.services.kolide.enable =
    lib.mkEnableOption "1Password Device Trust (Kolide launcher)";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.dotnix.core.secrets.enable;
        message = "dotnix.services.kolide: its enrollment secret is in secrets/ (core.secrets)";
      }
    ];

    sops.secrets.kolide-secret = {
      path = "/etc/kolide-k2/secret";
      mode = "0600";
    };

    services.kolide-launcher.enable = true;
    dotnix.services.cache.skip = [ "kolide-launcher" ];

    environment.persistence = lib.mkIf config.dotnix.storage.impermanence.enable {
      "/persist".directories = [ "/var/kolide-k2" ];
    };
  };
}
