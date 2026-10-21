# GPT: EFI, swap and LUKS with one btrfs (root, home, nix, persist, log and
# nodatacow subvolumes), found by label unless a host gives its own devices.
{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config.dotnix.storage.disk;
  part = name: "/dev/disk/by-partlabel/dotnix-${name}";
  subvol = name: extra: {
    device = "/dev/mapper/enc";
    fsType = "btrfs";
    options = [
      "subvol=${name}"
      "noatime"
    ]
    ++ extra;
  };
  compressed = name: subvol name [ "compress=zstd" ];
in
{
  options.dotnix.storage.disk = {
    enable = lib.mkEnableOption "the dotnix disk layout";
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
  };

  config = lib.mkIf cfg.enable {
    boot.initrd.luks.devices.enc = {
      device = cfg.luks;
      allowDiscards = true;
    };
    swapDevices = lib.optional (cfg.swap != null) {
      device = cfg.swap;
      randomEncryption.enable = true;
    };
    fileSystems = {
      "/" = compressed "root";
      "/home" = compressed "home";
      "/nix" = compressed "nix";
      "/persist" = compressed "persist" // {
        neededForBoot = true;
      };
      "/var/log" = compressed "log" // {
        neededForBoot = true;
      };
      "/var/lib/nodatacow" = subvol "nodatacow" [ ];
      "/boot" = {
        device = cfg.efi;
        fsType = "vfat";
        options = [ "umask=0077" ];
      };
    };
  };
}
