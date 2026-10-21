{
  config,
  lib,
  pkgs,
  dotlib,
  ...
}:
let
  cfg = config.dotnix.core.boot;
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
  options.dotnix.core.boot = {
    enable = lib.mkEnableOption "booting an encrypted btrfs disk";
    loader = mkOption {
      type = types.enum [ "grub" ];
      default = "grub";
    };
    kernel = mkOption {
      type = types.raw;
      default = pkgs.linuxPackages;
      example = lib.literalExpression "pkgs.linuxPackages_zen";
    };
    plymouth.enable = dotlib.mkItem cfg "the boot splash";
  };

  config = mkIf cfg.enable {
    boot = {
      kernelPackages = cfg.kernel;
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
        "boot.shell_on_fail"
        "rd.systemd.show_status=false"
        "systemd.show_status=false"
        # no blinking cursor between splash, display manager and shutdown
        "vt.global_cursor_default=0"
        "rd.udev.log_level=3"
        "udev.log_priority=3"
      ];
      plymouth = {
        inherit (cfg.plymouth) enable;
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
        systemd-boot.enable = false;
        timeout = 0;
        grub = {
          enable = true;
          device = "nodev";
          efiSupport = true;
          gfxmodeEfi = "1920x1200";
          efiInstallAsRemovable = true;
          # /boot is 1G and each initrd carries every plymouth theme (~75M)
          configurationLimit = 5;
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
