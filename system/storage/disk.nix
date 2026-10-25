# GPT: EFI, swap and LUKS with one btrfs (root, home, nix, persist, log and
# nodatacow subvolumes), declared with disko: the hosts mount it and
# dotnix-install formats it. Found by label unless a host gives its own devices.
{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config.dotnix.storage.disk;
  part = name: "/dev/disk/by-partlabel/dotnix-${name}";
  # the directories bind-mounted from the nodatacow subvolume
  nodatacowDirs = [
    "docker"
    "flatpak"
    "waydroid"
    "cloudflare-warp"
    "bitcoind"
  ];
  subvol = name: extra: {
    mountpoint = if name == "root" then "/" else "/${name}";
    mountOptions = [ "noatime" ] ++ extra;
  };
  compressed = name: subvol name [ "compress=zstd" ];
in
{
  options.dotnix.storage.disk = {
    enable = lib.mkEnableOption "the dotnix disk layout";
    device = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/dev/disk/by-id/nvme-Samsung_SSD_980_1TB_S64ANS0T000000";
      description = "The whole disk, read only when formatting (dotnix-install).";
    };
    luks = mkOption {
      type = types.str;
      default = part "luks";
      example = "/dev/disk/by-uuid/8e7e951a-5b4c-4bfe-92f2-57d1f88da1d7";
    };
    efi = mkOption {
      type = types.str;
      default = part "efi";
    };
    swap = mkOption {
      type = types.nullOr types.str;
      default = part "swap";
      description = "Swap partition, encrypted with a new random key at every boot.";
    };
    swapSize = mkOption {
      type = types.str;
      default = "16G";
      description = "Size of the swap partition when formatting.";
    };
    passwordFile = mkOption {
      type = types.str;
      default = "/tmp/dotnix-luks.key";
      description = "The LUKS password when formatting.";
    };
  };

  config = lib.mkIf cfg.enable {
    disko.devices.disk.main = {
      type = "disk";
      device = if cfg.device == null then "/dev/null" else cfg.device;
      content = {
        type = "gpt";
        partitions = {
          efi = {
            label = "dotnix-efi";
            device = cfg.efi;
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              extraArgs = [
                "-F"
                "32"
                "-n"
                "BOOT"
              ];
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          swap = lib.mkIf (cfg.swap != null) {
            label = "dotnix-swap";
            device = cfg.swap;
            size = cfg.swapSize;
            type = "8200";
            content = {
              type = "swap";
              randomEncryption = true;
            };
          };
          luks = {
            label = "dotnix-luks";
            device = cfg.luks;
            size = "100%";
            type = "8309";
            content = {
              type = "luks";
              name = "enc";
              inherit (cfg) passwordFile;
              extraFormatArgs = [
                "--type"
                "luks2"
                "--label"
                "dotnix"
              ];
              settings.allowDiscards = true;
              content = {
                type = "btrfs";
                extraArgs = [
                  "-f"
                  "-L"
                  "dotnix"
                ];
                subvolumes = {
                  root = compressed "root";
                  home = compressed "home";
                  nix = compressed "nix";
                  persist = compressed "persist";
                  log = compressed "log" // {
                    mountpoint = "/var/log";
                  };
                  nodatacow = subvol "nodatacow" [ ] // {
                    mountpoint = "/var/lib/nodatacow";
                  };
                };
                postCreateHook = ''
                  mnt=$(mktemp -d)
                  mount -o subvol=/ /dev/mapper/enc "$mnt"
                  chattr +C "$mnt/nodatacow"
                  mkdir -p ${lib.concatMapStringsSep " " (d: ''"$mnt/nodatacow/${d}"'') nodatacowDirs}
                  ${lib.optionalString config.dotnix.storage.impermanence.enable ''
                    [ -e "$mnt/root-blank" ] || btrfs subvolume snapshot -r "$mnt/root" "$mnt/root-blank"
                  ''}
                  umount "$mnt"
                  rmdir "$mnt"
                '';
              };
            };
          };
        };
      };
    };

    fileSystems = {
      "/persist".neededForBoot = true;
      "/var/log".neededForBoot = true;
      # impermanence binds from it too (big state, outside snapshots and backup)
      "/var/lib/nodatacow".neededForBoot = true;
    };
  };
}
