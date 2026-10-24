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
  luks = config.boot.initrd.luks.devices.enc;

  # the disk opens with the TPM and a PIN while the boot chain is the signed
  # one (PCR 7: Secure Boot's state and keys); the passphrase still works
  tpm2Enroll = pkgs.writeShellApplication {
    name = "dotnix-tpm2-enroll";
    runtimeInputs = [ config.systemd.package ];
    text = ''
      [ "$(id -u)" = 0 ] || exec sudo "$0" "$@"
      systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto --tpm2-with-pin=yes \
        --tpm2-pcrs=7 ${luks.device}
    '';
  };
in
{
  options.dotnix.core.boot = {
    enable = lib.mkEnableOption "booting an encrypted btrfs disk";
    loader = mkOption {
      type = types.enum [
        "grub"
        "limine"
      ];
      default = "grub";
      description = "limine for Secure Boot; grub picks the boot theme at boot time (desktop.bootScreens).";
    };
    # Limine signed with this host's own keys (sbctl, in /var/lib/sbctl), and
    # the hashes of kernels and initrds in its signed config: what boots
    # can't be swapped on the unencrypted /boot
    secureBoot.enable = lib.mkEnableOption "Secure Boot (Limine and sbctl; see the README first)";
    tpm2.enable = lib.mkEnableOption "unlocking the disk with the TPM and a PIN (`dotnix-tpm2-enroll` once)";
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
        limine = mkIf (cfg.loader == "limine") {
          enable = true;
          efiInstallAsRemovable = true;
          maxGenerations = 5;
          secureBoot = mkIf cfg.secureBoot.enable {
            enable = true;
            # the first rebuild with it makes the keys and, in Setup Mode,
            # enrolls them next to Microsoft's (GPU firmware needs those)
            autoGenerateKeys = true;
            autoEnrollKeys = {
              enable = true;
              # not --firmware-builtin: without the firmware's dbDefault (not
              # every one has it) it fails the whole enrollment
              extraArgs = [ "--microsoft" ];
            };
          };
          panicOnChecksumMismatch = cfg.secureBoot.enable;
        };
        grub = mkIf (cfg.loader == "grub") {
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

    assertions = [
      {
        assertion = cfg.secureBoot.enable -> cfg.loader == "limine";
        message = "dotnix.core.boot.secureBoot needs loader = \"limine\"";
      }
      {
        assertion = cfg.tpm2.enable -> cfg.secureBoot.enable;
        message = "dotnix.core.boot.tpm2 binds to Secure Boot (PCR 7): enable secureBoot first";
      }
    ];

    # sbctl's keys straight in /persist: no /var/lib/sbctl, which Limine reads
    # as "keys made" (a bind mount there would leave Limine unsigned), and
    # there before the rebuild that turns secureBoot on creates them
    environment.etc."sbctl/sbctl.conf" =
      mkIf (cfg.loader == "limine" && config.dotnix.storage.impermanence.enable)
        {
          text =
            let
              dir = "/persist/var/lib/sbctl";
              key = name: {
                privkey = "${dir}/keys/${name}/${name}.key";
                pubkey = "${dir}/keys/${name}/${name}.pem";
                type = "file";
              };
            in
            builtins.toJSON {
              landlock = true;
              keydir = "${dir}/keys";
              guid = "${dir}/GUID";
              files_db = "${dir}/files.json";
              bundles_db = "${dir}/bundles.json";
              keys = {
                pk = key "PK";
                kek = key "KEK";
                db = key "db";
              };
            };
        };
    environment.systemPackages =
      lib.optional cfg.secureBoot.enable pkgs.sbctl ++ lib.optional cfg.tpm2.enable tpm2Enroll;
    boot.initrd.luks.devices = mkIf cfg.tpm2.enable {
      enc.crypttabExtraOpts = [ "tpm2-device=auto" ];
    };

    # the splash stays on screen when plymouth quits, until the session draws
    # over it (no empty console in between)
    systemd.services.plymouth-quit.serviceConfig.ExecStart = [
      ""
      "-${config.boot.plymouth.package}/bin/plymouth quit --retain-splash"
    ];
  };
}
