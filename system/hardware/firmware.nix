# firmware updates through fwupd (LVFS): `fwupdmgr get-updates`, then
# `fwupdmgr update`; the Activity dashboard counts the pending ones
{
  config,
  lib,
  pkgs,
  ...
}:
let
  secureBoot = config.dotnix.core.boot.secureBoot.enable;
  # where fwupd looks for the EFI app it boots to flash a capsule (BIOS,
  # EC): built in as fwupd-efi's folder; with Secure Boot it takes only
  # the .signed one, which needs this machine's keys, so out of the store
  efi = "${pkgs.fwupd-efi}/libexec/fwupd/efi";
  signed = "/var/lib/fwupd/efi-signed";
in
{
  options.dotnix.hardware.firmware.enable = lib.mkEnableOption "firmware updates (fwupd)";

  config = lib.mkIf config.dotnix.hardware.firmware.enable {
    services.fwupd = {
      enable = true;
      # signed with this machine's keys: no shim in between
      uefiCapsuleSettings = lib.mkIf secureBoot { DisableShimForSecureBoot = true; };
    };

    # the app signed with sbctl's keys, as Limine is, at boot and after each
    # switch that changes it; fwupd sees that folder as fwupd-efi's own
    systemd.services.fwupd-efi-sign = lib.mkIf secureBoot {
      description = "Sign fwupd's EFI app for Secure Boot";
      wantedBy = [ "multi-user.target" ];
      before = [ "fwupd.service" ];
      unitConfig.RequiresMountsFor = "/var/lib/fwupd";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [
        pkgs.sbctl
        pkgs.coreutils
      ];
      script = ''
        install -d -m 755 ${signed}
        for app in ${efi}/*.efi; do
          name=$(basename "$app")
          install -m 644 "$app" ${signed}/"$name"
          sbctl sign -o ${signed}/"$name".signed "$app"
        done
      '';
    };
    systemd.services.fwupd = lib.mkIf secureBoot {
      requires = [ "fwupd-efi-sign.service" ];
      after = [ "fwupd-efi-sign.service" ];
      serviceConfig.BindReadOnlyPaths = [ "${signed}:${efi}" ];
    };
  };
}
