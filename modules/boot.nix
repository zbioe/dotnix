{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.boot;
  waitForGpu = pkgs.writeShellScript "wait-for-gpu" ''
    for _ in $(${pkgs.coreutils}/bin/seq 80); do
      for card in /sys/class/drm/card[0-9]*; do
        [ -e "$card/device/vendor" ] && exit 0
      done
      ${pkgs.coreutils}/bin/sleep 0.1
    done
    exit 0
  '';
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
      binfmt.emulatedSystems = [ "aarch64-linux" ];
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
        "systemd.show_status=false"
        # no blinking cursor between splash, display manager and shutdown
        "vt.global_cursor_default=0"
        "rd.udev.log_level=3"
        "udev.log_priority=3"
        # "mem_sleep_default=deep"
      ];
      plymouth = {
        enable = true;
        font = "${pkgs.hack-font}/share/fonts/truetype/Hack-Regular.ttf";
        logo = "${pkgs.nixos-icons}/share/icons/hicolor/128x128/apps/nix-snowflake.png";
      };
      # plymouth picks its splash as soon as it starts: before the GPU driver
      # is up it only has the text console, falls back to the text splash and
      # keeps it (boot messages on screen to the end). So it starts once a
      # real GPU (a DRM card on PCI, not the firmware's simpledrm) is there,
      # waiting at most 8s.
      initrd.systemd = {
        storePaths = [ waitForGpu ];
        services.plymouth-start.serviceConfig.ExecStartPre = [ "${waitForGpu}" ];
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

    # the splash stays on screen when plymouth quits, until the session draws
    # over it (no empty console in between)
    systemd.services.plymouth-quit.serviceConfig.ExecStart = [
      ""
      "-${config.boot.plymouth.package}/bin/plymouth quit --retain-splash"
    ];
  };
}
