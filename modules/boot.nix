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
      initrd = {
        systemd.enable = true;
        verbose = false;
        availableKernelModules = [
          "nvme"
          "xhci_pci"
          "usb_storage"
          "sd_mod"
        ];
        kernelModules = [
          "xhci_pci"
          "usb_storage"
          "uas"
          "usbcore"
        ];
      };
      kernelModules = [
        "vfat"
        "uas"
        "usb_storage"
        "usbcore"
        "xhci_pci"
        "cryptd"
        "nls_cp437"
        "nls_iso8859_1"
      ];
      # silent boot
      kernelParams = [
        "quiet"
        "splash"
        "intremap=on"
        "boot.shell_on_fail"
        "rd.systemd.show_status=false"
        "rd.udev.log_level=3"
        "udev.log_priority=3"
        # "mem_sleep_default=deep"
      ];
      plymouth = {
        enable = true;
        font = "${pkgs.hack-font}/share/fonts/truetype/Hack-Regular.ttf";
        logo = "${pkgs.nixos-icons}/share/icons/hicolor/128x128/apps/nix-snowflake.png";
      };
      supportedFilesystems = {
        btrfs = true;
      };
      loader = {
        efi.canTouchEfiVariables = false;
        # make sure system-boot is disabled
        systemd-boot.enable = false;
        timeout = 0;
        grub = {
          enable = true;
          device = "nodev";
          efiSupport = true;
          enableCryptodisk = true;
          gfxmodeEfi = "1920x1200";
          efiInstallAsRemovable = true;
        };
      };
    };
  };
}
