# The format script dotnix-install runs (system/storage/disk.nix), on an empty disk
{ format }:
{ pkgs, ... }:
{
  name = "dotnix-disk";

  nodes.machine = {
    virtualisation = {
      emptyDiskImages = [ 2048 ]; # vdb
      memorySize = 2048;
    };
    environment.systemPackages = with pkgs; [
      cryptsetup
      btrfs-progs
      e2fsprogs
    ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.succeed("printf secret > /tmp/dotnix-luks.key")
    machine.succeed("${format}/bin/disko-destroy-format-mount --yes-wipe-all-disks >&2")

    with subtest("partitions by label"):
        for p in ["efi", "swap", "luks"]:
            machine.succeed(f"test -b /dev/disk/by-partlabel/dotnix-{p}")
        machine.succeed("cryptsetup luksDump /dev/disk/by-partlabel/dotnix-luks | grep -q 'Label:.*dotnix'")
        machine.succeed("cryptsetup open --test-passphrase --key-file /tmp/dotnix-luks.key /dev/disk/by-partlabel/dotnix-luks")

    with subtest("subvolumes mounted on /mnt"):
        for m in ["", "/home", "/nix", "/persist", "/var/log", "/var/lib/nodatacow"]:
            machine.succeed(f"findmnt -n -t btrfs /mnt{m}")
        machine.succeed("findmnt -n -t vfat /mnt/boot")
        machine.succeed("findmnt -no OPTIONS /mnt/home | grep -q compress=zstd")

    with subtest("root-blank and nodatacow"):
        machine.succeed("mkdir /top && mount -o subvol=/ /dev/mapper/enc /top")
        machine.succeed("btrfs property get -ts /top/root-blank ro | grep -q true")
        machine.succeed("lsattr -d /top/nodatacow | grep -q C")
        machine.succeed("test -d /top/nodatacow/docker")
  '';
}
