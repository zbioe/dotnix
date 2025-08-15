{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.boot;
  inherit (lib) types mkOption mkIf;
in
{
  options.modules.boot = with types; {
    enable = mkOption {
      type = bool;
      default = true;
      description = ''
        Enable boot for encrypted btrfs. Use grub.
      '';
    };
    kernelPackages = mkOption {
      type = raw;
      default = pkgs.linuxPackages;
      example = pkgs.linuxPackages_latest;
      description = ''
        The kernel packages to use.
      '';
    };
  };
  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.enable || cfg.loader.grub.enable || cfg.loader.systemd-boot.enable;
        message = "enable one bootloader or the system will not boot after disable this module.";
      }
    ];
    boot = {
      inherit (cfg) kernelPackages;
      consoleLogLevel = 0;
      initrd.verbose = false;
      plymouth = {
        enable = true;
      };
      supportedFilesystems = {
        btrfs = true;
      };
      loader = {
        efi.canTouchEfiVariables = true;
        # make sure system-boot is disabled
        systemd-boot.enable = false;
        timeout = 0;
        grub = {
          enable = true;
          device = "nodev";
          efiSupport = true;
          enableCryptodisk = true;
        };
      };
    };
  };
}
