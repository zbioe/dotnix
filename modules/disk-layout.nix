# The disk of hosts installed by `dotnix-install` (iso/tools.nix): GPT with
# an EFI partition, swap and LUKS, found by partition name (no UUIDs to
# copy around); inside LUKS one btrfs with the subvolumes root, home, nix,
# persist, log and nodatacow (no copy-on-write: VM images, containers).
# With `impermanence` the root goes back to the empty root-blank at every
# boot (like bx) and only /persist, /home and /nix keep state.
{
  config,
  lib,
  ...
}:
let
  inherit (lib) types mkOption mkIf;
  cfg = config.modules.disk;

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
  options.modules.disk = with types; {
    enable = mkOption {
      type = bool;
      default = false;
      description = "Disk layout made by dotnix-install.";
    };
    impermanence = mkOption {
      type = bool;
      default = true;
      description = "Reset / to root-blank at every boot; state lives in /persist.";
    };
  };

  config = mkIf cfg.enable {
    boot.initrd.luks.devices.enc = {
      device = part "luks";
      allowDiscards = true;
    };
    swapDevices = [ { device = part "swap"; } ];

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
        device = part "efi";
        fsType = "vfat";
        options = [ "umask=0077" ];
      };
    };

    # the empty root, back at every boot
    boot.initrd.systemd.services.rollback = mkIf cfg.impermanence {
      description = "Reset the btrfs root subvolume to root-blank";
      wantedBy = [ "initrd.target" ];
      after = [ "systemd-cryptsetup@enc.service" ];
      before = [ "sysroot.mount" ];
      unitConfig.DefaultDependencies = "no";
      serviceConfig.Type = "oneshot";
      script = ''
        mkdir -p /mnt
        mount -o subvolid=5 /dev/mapper/enc /mnt
        delete() {
          for sub in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
            delete "/mnt/$sub"
          done
          btrfs subvolume delete "$1"
        }
        if [ -e /mnt/root-blank ]; then
          [ -d /mnt/root ] && delete /mnt/root
          btrfs subvolume snapshot /mnt/root-blank /mnt/root
        fi
        umount /mnt
      '';
    };

    # what has to outlive the reset (same as bx)
    environment.persistence."/persist" = mkIf cfg.impermanence {
      hideMounts = true;
      directories = [
        "/var/lib/bluetooth"
        "/var/lib/nixos"
        "/var/lib/systemd/coredump"
        "/var/lib/systemd/resolved"
        "/etc/NetworkManager/system-connections"
      ];
      files = [
        "/etc/machine-id"
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_ed25519_key.pub"
        "/etc/ssh/ssh_host_rsa_key"
        "/etc/ssh/ssh_host_rsa_key.pub"
      ];
    };

    # docker on the no-copy-on-write subvolume, like the binds in default/
    # (dotnix-install creates their directories)
    fileSystems."/var/lib/docker" = {
      device = "/var/lib/nodatacow/docker";
      fsType = "none";
      options = [ "bind" ];
    };
  };
}
