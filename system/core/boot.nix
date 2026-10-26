{
  config,
  lib,
  pkgs,
  unstable,
  dotlib,
  ...
}:
let
  cfg = config.dotnix.core.boot;
  # (enrolls on firmware that leaves its empty keys in place)
  sbctl = pkgs.callPackage ../../pkgs/sbctl { };
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
  # one (PCR 7: Secure Boot's state and keys); the passphrase still works.
  # --offer (dotnix-firstboot): asks first, and only when not enrolled yet
  tpm2Enroll = pkgs.writeShellApplication {
    name = "dotnix-tpm2-enroll";
    runtimeInputs = [
      config.systemd.package
      pkgs.coreutils
      pkgs.gnugrep
    ];
    text = ''
      [ "$(id -u)" = 0 ] || exec sudo "$0" "$@"
      if [ "''${1:-}" = --offer ]; then
        systemd-cryptenroll ${luks.device} | grep -qw tpm2 && exit 0
      fi
      sb=$(od -An -t u1 /sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c 2>/dev/null || true)
      if [ "''${sb##* }" != 1 ]; then
        echo "Secure Boot is off: turn it on in the firmware setup, then dotnix-tpm2-enroll" >&2
        [ "''${1:-}" = --offer ] && exit 0
        exit 1
      fi
      if [ "''${1:-}" = --offer ]; then
        read -rp "Open the disk with the TPM and a PIN from now on (the passphrase keeps working)? [Y/n] " a
        [[ $a != [nN]* ]] || exit 0
      fi
      systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto --tpm2-with-pin=yes \
        --tpm2-pcrs=7 ${luks.device}
    '';
  };

  # this host's Secure Boot keys to a machine being installed (dotnix-install
  # waits for them in its live system): one set of keys for every host, so a
  # stick signed on one boots on all of them
  sbctlDir = if config.dotnix.storage.impermanence.enable then "/persist/var/lib" else "/var/lib";
  sbctlSend = pkgs.writeShellApplication {
    name = "dotnix-sbctl-send";
    runtimeInputs = with pkgs; [
      gnutar
      openssh
    ];
    text = ''
      [ $# -ge 1 ] || { echo "usage: dotnix-sbctl-send [SSH OPTION...] ADDRESS (of the live system installing)" >&2; exit 2; }
      sudo test -f ${sbctlDir}/sbctl/keys/db/db.key || { echo "no Secure Boot keys here yet" >&2; exit 1; }
      sudo tar -C ${sbctlDir} -cf - sbctl |
        ssh "''${@:1:$#-1}" "${config.dotnix.core.user.name}@''${!#}" 'umask 077; cat > /tmp/dotnix-sbctl.tar.part && mv /tmp/dotnix-sbctl.tar.part /tmp/dotnix-sbctl.tar'
      echo "sent: dotnix-install goes on"
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
        # Limine has no key to show a menu at 0: a blank second, any key shows it
        timeout = if cfg.loader == "limine" then 1 else 0;
        limine = mkIf (cfg.loader == "limine") {
          enable = true;
          # 12.9.1+: a key during the quiet second no longer leaves the menu blank
          package = unstable.limine;
          extraConfig = "quiet: yes";
          efiInstallAsRemovable = true;
          maxGenerations = 5;
          secureBoot = mkIf cfg.secureBoot.enable {
            enable = true;
            inherit sbctl;
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

    # sbctl's keys straight in /persist (so in the daily backup too,
    # system/storage/backup.nix): no /var/lib/sbctl, which Limine reads
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
    # Limine sits at the removable path (it boots wherever the firmware's
    # entries are lost), which the firmware lists as "UEFI OS": an entry
    # named NixOS for it, written once
    systemd.services.dotnix-boot-entry = mkIf (cfg.loader == "limine") {
      description = "A firmware boot entry named NixOS for Limine";
      wantedBy = [ "multi-user.target" ];
      unitConfig = {
        RequiresMountsFor = "/boot";
        ConditionPathExists = "/sys/firmware/efi/efivars";
      };
      serviceConfig.Type = "oneshot";
      path = with pkgs; [
        efibootmgr
        util-linux
        gnugrep
        coreutils
      ];
      script = ''
        efibootmgr | grep -q '^Boot[0-9A-F]\{4\}\*\? NixOS\b' && exit 0
        part=$(findmnt -no SOURCE /boot)
        n=$(cat "/sys/class/block/$(basename "$part")/partition")
        efibootmgr -q -c -d "/dev/$(lsblk -no PKNAME "$part")" -p "$n" -L NixOS -l '\EFI\BOOT\BOOTX64.EFI'
      '';
    };
    environment.systemPackages =
      lib.optionals cfg.secureBoot.enable [
        sbctl
        sbctlSend
      ]
      ++ lib.optional cfg.tpm2.enable tpm2Enroll;
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
