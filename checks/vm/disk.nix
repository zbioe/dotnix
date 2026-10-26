# What dotnix-install does, on a VM: the disko script formats the disk
# (system/storage/disk.nix), nixos-install puts a system on it, and that
# system boots from it: LUKS password, GRUB EFI, / wiped and /persist kept.
{
  inputs,
  dotlib,
  unstable,
}:
{ pkgs, lib, ... }:
let
  target = inputs.nixpkgs.lib.nixosSystem {
    inherit (pkgs.stdenv.hostPlatform) system;
    specialArgs = { inherit dotlib unstable; };
    modules = [
      inputs.disko.nixosModules.disko
      inputs.impermanence.nixosModules.impermanence
      ../../system/core/boot.nix
      ../../system/storage/disk.nix
      ../../system/storage/impermanence.nix
      "${inputs.nixpkgs}/nixos/modules/profiles/qemu-guest.nix"
      "${inputs.nixpkgs}/nixos/modules/testing/test-instrumentation.nix"
      {
        dotnix = {
          core.boot = {
            enable = true;
            plymouth.enable = false;
          };
          storage = {
            disk = {
              enable = true;
              device = "/dev/vda";
              swapSize = "256M";
            };
            impermanence.enable = true;
          };
        };
        # the passphrase prompt on the console the test reads
        boot.kernelParams = [ "console=ttyS0" ];
        boot.binfmt.emulatedSystems = lib.mkForce [ ];
        boot.consoleLogLevel = lib.mkForce 7;
        documentation.enable = false;
        system.stateVersion = lib.trivial.release;
      }
    ];
  };
  inherit (target.config.system.build) toplevel destroyFormatMount;
in
{
  name = "dotnix-disk";

  nodes = {
    installer = {
      virtualisation = {
        # the target's disk is vda; the installer runs from vdb
        diskImage = "./target.qcow2";
        diskSize = 6 * 1024;
        emptyDiskImages = [ 1024 ];
        rootDevice = "/dev/vdb";
        memorySize = 2048;
        additionalPaths = [ toplevel ];
        fileSystems."/".autoFormat = true;
      };
      imports = [ "${inputs.nixpkgs}/nixos/tests/common/auto-format-root-device.nix" ];
      environment.systemPackages = with pkgs; [
        cryptsetup
        btrfs-progs
        e2fsprogs
        dosfstools
      ];
      nix.settings.substituters = lib.mkForce [ ];
    };
    target = {
      virtualisation = {
        diskImage = "./target.qcow2";
        memorySize = 2048;
        useBootLoader = true;
        useEFIBoot = true;
        useDefaultFilesystems = false;
        efi.keepVariables = false;
        fileSystems."/" = {
          device = "/dev/disk/by-label/unused";
          fsType = "ext4";
        };
      };
    };
  };

  testScript = ''
    installer.start()
    installer.wait_for_unit("multi-user.target")
    installer.succeed("udevadm settle")
    installer.succeed("printf secret > /tmp/dotnix-luks.key")
    # what another OS left (as on bx): a BIOS boot partition holding a FAT
    # with a shim, which the firmware lists as an entry again on every boot
    installer.succeed(
        "udevadm lock --device=/dev/vda sh -c \"echo 'size=3M, type=21686148-6449-6E6F-744E-656564454649' | sfdisk -X gpt /dev/vda && mkfs.vfat /dev/vda1\""
    )
    installer.succeed("mkdir -p /old && mount /dev/vda1 /old && mkdir -p /old/EFI/fedora && touch /old/EFI/fedora/shimx64.efi && umount /old")
    installer.succeed("${destroyFormatMount}/bin/disko-destroy-format-mount --yes-wipe-all-disks >&2")

    with subtest("partitions by label, nothing left from before"):
        assert installer.succeed("lsblk -nro PARTLABEL /dev/vda | sed /^$/d").split() == ["dotnix-efi", "dotnix-swap", "dotnix-luks"]
        installer.fail("test -e /mnt/boot/EFI/fedora")
        for p in ["efi", "swap", "luks"]:
            installer.succeed(f"test -b /dev/disk/by-partlabel/dotnix-{p}")
        installer.succeed("cryptsetup luksDump /dev/disk/by-partlabel/dotnix-luks | grep -q 'Label:.*dotnix'")
        installer.succeed("cryptsetup open --test-passphrase --key-file /tmp/dotnix-luks.key /dev/disk/by-partlabel/dotnix-luks")

    with subtest("subvolumes mounted on /mnt"):
        for m in ["", "/home", "/nix", "/persist", "/var/log", "/var/lib/nodatacow"]:
            installer.succeed(f"findmnt -n -t btrfs /mnt{m}")
        installer.succeed("findmnt -n -t vfat /mnt/boot")
        installer.succeed("findmnt -no OPTIONS /mnt/home | grep -q compress=zstd")

    with subtest("root-blank and nodatacow"):
        installer.succeed("mkdir /top && mount -o subvol=/ /dev/mapper/enc /top")
        installer.succeed("btrfs property get -ts /top/root-blank ro | grep -q true")
        installer.succeed("lsattr -d /top/nodatacow | grep -q C")
        installer.succeed("test -d /top/nodatacow/docker")
        installer.succeed("umount /top")

    with subtest("install"):
        installer.succeed("nixos-install --system ${toplevel} --no-root-passwd --no-channel-copy >&2")
        installer.succeed("umount -R /mnt && cryptsetup close enc && sync")
        installer.shutdown()

    target.state_dir = installer.state_dir

    def boot():
        target.start()
        target.wait_for_console_text("passphrase for")
        target.send_console("secret\n")
        target.wait_for_unit("multi-user.target")

    with subtest("boots from its disk"):
        boot()
        target.succeed("findmnt -no SOURCE / | grep -q /dev/mapper/enc")
        target.succeed("findmnt -no OPTIONS / | grep -q subvol=/root")
        target.succeed("test -e /boot/EFI/BOOT/BOOTX64.EFI")
        target.wait_for_unit("swap.target")
        target.succeed("grep -q /dev/dm- /proc/swaps")
        machine_id = target.succeed("cat /etc/machine-id")
        # systemd-creds' key: made in /persist on the first boot, bind mounted
        target.succeed("findmnt /var/lib/systemd/credential.secret")
        sealed = target.succeed("echo kept | systemd-creds encrypt - - | base64 -w0")
        target.succeed("touch /gone /persist/kept && sync")
        target.shutdown()

    with subtest("/ is wiped, /persist is kept"):
        boot()
        target.fail("test -e /gone")
        target.succeed("test -e /persist/kept")
        assert target.succeed("cat /etc/machine-id") == machine_id
        assert target.succeed(f"echo {sealed} | base64 -d | systemd-creds decrypt - -").strip() == "kept"
        target.shutdown()
  '';
}
