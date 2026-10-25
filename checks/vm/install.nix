# dotnix-install itself, as the full ISO runs it: the live system
# (iso/live.nix) offline, the answers typed in, the whole desktop installed on
# an empty disk, and that disk booted, with Secure Boot (new keys: the
# firmware starts in Setup Mode).
{
  modules,
  specialArgs,
  nixpkgs,
}:
{ lib, ... }:
let
  instrumentation = "${nixpkgs}/nixos/modules/testing/test-instrumentation.nix";
  answers = lib.concatStringsSep "\\n" [
    "/dev/vda" # disk
    "vmtest" # host
    "1" # impermanence
    "16" # swap in GiB: room for nix copying from the ISO
    "secret" # disk password
    "secret"
    "login" # user password
    "login"
    "3" # Secure Boot: new keys
    "/dev/vda" # confirm
  ];
in
{
  name = "dotnix-install";

  node = {
    inherit specialArgs;
    # the live system sets nixpkgs.config and overlays, as the hosts do
    pkgsReadOnly = false;
  };

  nodes = {
    installer =
      { pkgs, ... }:
      {
        imports = modules ++ [ ../../iso/live.nix ];
        virtualisation = {
          useSecureBoot = true;
          efi.OVMF = pkgs.OVMFFull.fd;
          # the target's disk is vda; the live system runs from vdb
          diskImage = "./target.qcow2";
          diskSize = 160 * 1024;
          emptyDiskImages = [ (16 * 1024) ];
          rootDevice = "/dev/vdb";
          fileSystems."/".autoFormat = true;
          useEFIBoot = true;
          memorySize = 8 * 1024;
          cores = 6;
        };
        # a disk with a serial, as real ones have
        services.udev.extraRules = ''
          KERNEL=="vda", SYMLINK+="disk/by-id/virtio-dotnix-target"
        '';
        nix.settings.substituters = lib.mkForce [ ];
        networking.useDHCP = lib.mkForce false;
      };
    target =
      { pkgs, ... }:
      {
        virtualisation = {
          useSecureBoot = true;
          efi.OVMF = pkgs.OVMFFull.fd;
          diskImage = "./target.qcow2";
          memorySize = 4096;
          cores = 4;
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
    installer.succeed("test -d /sys/firmware/efi")

    with subtest("dotnix-install, offline"):
        status, _ = installer.execute("printf '${answers}\\n' | dotnix-install >&2", timeout=None)
        # what it wrote, to rebuild the same host when it fails
        installer.execute("cat /mnt/home/zbioe/dotnix/hosts/vmtest/*.nix >&2")
        assert status == 0, "dotnix-install failed"

    with subtest("the host and the flake it wrote"):
        flake = "/mnt/home/zbioe/dotnix"
        host = installer.succeed(f"cat {flake}/hosts/vmtest/default.nix")
        print(host)
        assert 'device = "/dev/disk/by-id/virtio-dotnix-target"' in host
        assert 'swapSize = "16G"' in host
        assert "impermanence.enable = true" in host
        assert 'passwordFile = "/persist/secrets/zbioe.passwd"' in host
        assert "secureBoot.enable = true" in host
        installer.succeed("test -f /mnt/persist/var/lib/sbctl/keys/db/db.key")
        # enrolled: out of Setup Mode
        assert installer.succeed("od -An -t u1 /sys/firmware/efi/efivars/SetupMode-*").split()[-1] == "0"
        # nixos-hardware from what it found (a VM, no battery), for the first
        # rebuild online: out of the offline reinstall below
        hardware = installer.succeed(f"cat {flake}/hosts/vmtest/hardware.nix")
        print(hardware)
        assert "inputs.hardware.nixosModules.common-pc\n" in hardware
        installer.succeed(f"echo '{{ }}' > {flake}/hosts/vmtest/hardware.nix")
        installer.succeed(f"grep -q qemu-guest {flake}/hosts/vmtest/hardware-configuration.nix")
        installer.succeed(f"test $(stat -c %u {flake}/flake.nix) = 1000")
        installer.succeed(f"git -c safe.directory='*' -C {flake} ls-files --error-unmatch hosts/vmtest/default.nix")
        installer.succeed("grep -q '^\\$y\\$' /mnt/persist/secrets/zbioe.passwd")
        installer.succeed("test ! -e /tmp/dotnix-luks.key")
        installer.succeed("test -e /mnt/boot/EFI/BOOT/BOOTX64.EFI")

    with subtest("the test driver in the installed system"):
        # the same host, plus what lets this test talk to it
        installer.succeed(
            f"sed -i 's|./hardware-configuration.nix|./hardware-configuration.nix ${instrumentation} ./vmtest.nix|' {flake}/hosts/vmtest/default.nix",
            "echo '{ lib, ... }: { boot.kernelParams = [ \"console=ttyS0\" ]; boot.consoleLogLevel = lib.mkForce 7; dotnix.core.boot.plymouth.enable = false; }' > " + flake + "/hosts/vmtest/vmtest.nix",
        )
        installer.succeed(f"nixos-install --flake path:{flake}#vmtest --no-root-passwd --no-channel-copy --option always-allow-substitutes true >&2", timeout=None)
        installer.succeed("umount -R /mnt && cryptsetup close enc && sync")
        installer.shutdown()

    target.state_dir = installer.state_dir
    # the same firmware, with the keys enrolled
    import shutil
    shutil.copy(installer.state_dir / "dotnix-live-efi-vars.fd", installer.state_dir / "target-efi-vars.fd")

    def boot():
        target.start()
        target.wait_for_console_text("passphrase for")
        target.send_console("secret\n")
        target.wait_for_unit("multi-user.target")

    with subtest("boots the installed disk"):
        boot()
        assert target.succeed("hostname").strip() == "vmtest"
        assert target.succeed("od -An -t u1 /sys/firmware/efi/efivars/SecureBoot-*").split()[-1] == "1"
        target.succeed("test -e /boot/limine/limine.conf")
        target.succeed("findmnt -no OPTIONS / | grep -q subvol=/root")
        target.succeed("test -d /home/zbioe/dotnix/hosts/vmtest")
        target.succeed("command -v dotnix-enroll")
        # the hash dotnix-install saved, not weakPass
        target.succeed('cut -d: -f1,2 /etc/shadow | grep -qxF "zbioe:$(cat /persist/secrets/zbioe.passwd)"')
        target.wait_for_unit("display-manager.service")
        target.succeed("touch /gone /persist/kept && sync")
        # services' state that outlives the root reset (/persist, nodatacow)
        state = ["/var/lib/private/open-webui", "/var/lib/private/ollama", "/var/lib/NetworkManager", "/var/lib/libvirt"]
        for d in state:
            target.succeed(f"mkdir -p {d} && touch {d}/kept")
        target.succeed("sync")
        target.shutdown()

    with subtest("/ is wiped, /persist is kept"):
        boot()
        target.fail("test -e /gone")
        target.succeed("test -e /persist/kept")
        for d in state:
            target.succeed(f"test -e {d}/kept")
        assert target.succeed("stat -c %a /var/lib/private").strip() == "700"
        target.shutdown()
  '';
}
