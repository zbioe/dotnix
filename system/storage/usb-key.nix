{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let
  inherit (lib) types mkOption mkIf;
  cfg = config.dotnix.storage.usbKey;
  luks = config.boot.initrd.luks.devices.${cfg.luksName};
  dotnixKey = pkgs.callPackage ../../pkgs/dotnix-key { };
  askPassword = "${config.boot.initrd.systemd.package}/bin/systemd-ask-password";
  cryptsetupUnit = "systemd-cryptsetup@${utils.escapeSystemdPath cfg.luksName}.service";
in
{
  options.dotnix.storage.usbKey = with types; {
    enable = mkOption {
      type = bool;
      default = false;
      description = "Unlock LUKS with a key hidden in the gap of any USB stick (`dotnix-key create`).";
    };
    luksName = mkOption {
      type = str;
      default = "enc";
      description = "The boot.initrd.luks.devices entry it unlocks.";
    };
    timeout = mkOption {
      type = ints.positive;
      default = 10;
      description = "Seconds to wait for a stick before asking the passphrase.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.boot.initrd.systemd.enable;
        message = "dotnix.storage.usbKey needs boot.initrd.systemd.enable";
      }
    ];

    environment.systemPackages = [ dotnixKey ];

    boot.initrd.availableKernelModules = [
      "usb_storage"
      "uas"
      "sd_mod"
    ];
    boot.initrd.systemd.storePaths = [
      (lib.getExe dotnixKey)
      (lib.getExe' pkgs.cryptsetup "cryptsetup")
      askPassword
    ];
    boot.initrd.systemd.services.dotnix-key = {
      description = "Unlock ${cfg.luksName} with a USB stick key";
      wantedBy = [ "initrd.target" ];
      before = [ cryptsetupUnit ];
      after = [ "systemd-udev-trigger.service" ];
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = lib.escapeShellArgs (
          [
            (lib.getExe dotnixKey)
            "unlock"
            "-device"
            luks.device
            "-name"
            cfg.luksName
            "-timeout"
            "${toString cfg.timeout}s"
            "-ask-password"
            askPassword
          ]
          ++ lib.optional luks.allowDiscards "-allow-discards"
          ++ lib.optionals luks.bypassWorkqueues [
            "-no-read-workqueue"
            "-no-write-workqueue"
          ]
        );
      };
    };
  };
}
