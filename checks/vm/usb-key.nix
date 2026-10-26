{ pkgs, lib, ... }:
let
  dotnixKey = pkgs.callPackage ../../pkgs/dotnix-key { };
in
{
  name = "dotnix-usb-key";

  nodes.machine = {
    imports = [ ../../system/storage/usb-key.nix ];
    virtualisation = {
      emptyDiskImages = [
        512 # vdb: this machine's LUKS root
        64 # vdc: another machine's LUKS
        64 # vdd: that machine's stick, always plugged
      ];
      useBootLoader = true;
      useEFIBoot = true;
      mountHostNixStore = true;
      memorySize = 2048;
      qemu.options = [ "-device qemu-xhci,id=xhci" ];
    };
    boot.loader.systemd-boot.enable = true;
    boot.initrd.systemd.enable = true;
    boot.initrd.availableKernelModules = [ "xhci_pci" ];
    environment.systemPackages = [
      dotnixKey
      pkgs.cryptsetup
      pkgs.dosfstools
    ];

    specialisation.boot-luks.configuration = {
      boot.initrd.luks.devices = lib.mkVMOverride { enc.device = "/dev/vdb"; };
      virtualisation.rootDevice = "/dev/mapper/enc";
      dotnix.storage.usbKey = {
        enable = true;
        timeout = 30;
      };
      boot.initrd.systemd.services.dotnix-key.serviceConfig.StandardError = "journal+console";
    };
  };

  testScript =
    { nodes, ... }:
    let
      boot-luks = nodes.machine.specialisation.boot-luks.configuration.system.build.toplevel;
    in
    # python
    ''
      import queue, re, time

      pending = ""

      # wait_for_console_text with a timeout reads one line a second: too slow for a boot log
      def console(text, timeout=300):
          global pending
          deadline = time.monotonic() + timeout
          while True:
              try:
                  while True:
                      pending += machine.last_lines.get(block=False) + "\n"
              except queue.Empty:
                  pass
              m = re.search(text, pending)
              if m:
                  pending = pending[m.end():]
                  return
              if time.monotonic() > deadline:
                  raise Exception(f"{text!r} not on the console after {timeout}s")
              time.sleep(0.1)

      def boot():
          global pending
          machine.succeed("sync")
          machine.crash()
          pending = ""
          machine.start()

      def plug(name):
          path = machine.state_dir / f"{name}.img"
          if not path.exists():
              with open(path, "wb") as f:
                  f.truncate(64 << 20)
          machine.send_monitor_command(f"drive_add 0 if=none,id={name},file={path},format=raw")
          machine.send_monitor_command(f"device_add usb-storage,id=dev-{name},drive={name},bus=xhci.0")

      def unplug(name):
          machine.send_monitor_command(f"device_del dev-{name}")

      def stick(dev, label, table="dos"):
          machine.succeed(f"echo 'label: {table}' | sfdisk -q {dev} && echo 'start=2048' | sfdisk -q -a {dev}")
          machine.succeed(f"udevadm settle && mkfs.vfat -n {label} {dev}1 && mkdir -p /stick && mount {dev}1 /stick && echo music > /stick/song.txt && umount /stick")

      def slots():
          return int(machine.succeed("cryptsetup luksDump /dev/vdb | grep -cE '^ +[0-9]+: luks2'"))


      def booted():
          machine.wait_for_unit("multi-user.target")
          assert "/dev/mapper/enc on / type ext4" in machine.succeed("mount")

      with subtest("volumes and sticks"):
          machine.wait_for_unit("multi-user.target")
          machine.succeed("echo -n pass | cryptsetup luksFormat -q --pbkdf pbkdf2 --iter-time 1 /dev/vdb -")
          machine.succeed("echo -n pass | cryptsetup open /dev/vdb enc -")
          machine.succeed("mkfs.ext4 -q /dev/mapper/enc && cryptsetup close enc")
          machine.succeed("echo -n other | cryptsetup luksFormat -q --pbkdf pbkdf2 --iter-time 1 /dev/vdc -")
          stick("/dev/vdd", "OTHER")
          machine.succeed("echo -n other | dotnix-key create -yes -luks /dev/vdc /dev/vdd")

          plug("plain")
          machine.wait_until_succeeds("test -b /dev/sda")
          stick("/dev/sda", "PLAIN")
          out = machine.succeed("echo -n pass | dotnix-key create -yes -luks /dev/vdb /dev/sda")
          assert "opens /dev/vdb" in out, out
          unplug("plain")

          plug("withpin")
          machine.wait_until_succeeds("test -b /dev/sda")
          stick("/dev/sda", "WITHPIN")
          machine.succeed("echo -n 1234 > /tmp/pin")
          out = machine.succeed("echo -n pass | dotnix-key create -yes -pin-file /tmp/pin -luks /dev/vdb /dev/sda")
          assert "with PIN" in out, out
          unplug("withpin")

          plug("legacy")
          machine.wait_until_succeeds("test -b /dev/sda")
          machine.succeed("echo 'label: dos' | sfdisk -q /dev/sda && echo 'start=3616, type=7' | sfdisk -q -a /dev/sda")
          machine.succeed("head -c 4096 /dev/urandom > /tmp/legacy && dd if=/tmp/legacy of=/dev/sda bs=1 seek=2048 conv=fsync status=none")
          machine.succeed("echo -n pass | cryptsetup luksAddKey -q --pbkdf pbkdf2 --iter-time 1 /dev/vdb /tmp/legacy")
          before = slots()
          machine.succeed("dotnix-key adopt -yes -luks /dev/vdb /dev/sda")
          assert slots() == before, "adopt changed LUKS"
          machine.fail("cmp -n 4096 -i 0:2048 /tmp/legacy /dev/sda")
          unplug("legacy")

          plug("gpt")
          machine.wait_until_succeeds("test -b /dev/sda")
          stick("/dev/sda", "GPT", "gpt")
          table = machine.succeed("sfdisk --dump /dev/sda")
          machine.succeed("echo -n pass | dotnix-key create -yes -luks /dev/vdb /dev/sda")
          assert machine.succeed("sfdisk --dump /dev/sda") == table, "the GPT changed"
          machine.succeed("sfdisk --verify /dev/sda")
          machine.succeed("mount -o ro /dev/sda1 /stick && grep -q music /stick/song.txt && umount /stick")
          unplug("gpt")
          assert slots() == 5, slots()

          listing = machine.succeed("dotnix-key list")
          assert "/dev/vdd" in listing and "opens /dev/vdc" in listing, listing
          machine.succeed("${boot-luks}/bin/switch-to-configuration boot")
          entry = machine.succeed("cd /boot/loader/entries && ls *boot-luks*.conf").strip()
          machine.succeed(f"bootctl set-default {entry}")

      with subtest("no stick: the passphrase"):
          boot()
          console("asking the passphrase")
          console("Please enter passphrase for disk")
          machine.send_console("pass\n")
          booted()

      with subtest("stick plugged while waiting: no passphrase"):
          boot()
          time.sleep(8)
          plug("plain")
          console("enc opened with the key on /dev/sda")
          booted()
          journal = machine.succeed("journalctl -b --no-pager")
          assert "Please enter passphrase" not in journal
          assert "systemd-cryptsetup@enc.service: Failed" not in journal

      with subtest("rewriting a stick keeps its files and revokes its old key"):
          old = machine.succeed("dotnix-key list")
          out = machine.succeed("echo -n pass | dotnix-key create -yes -luks /dev/vdb /dev/sda")
          assert "Revoked slot" in out, out
          assert slots() == 5, slots()
          machine.succeed("mkdir -p /stick && mount -o ro /dev/sda1 /stick && grep -q music /stick/song.txt && umount /stick")

      with subtest("rewritten stick from the start"):
          boot()
          plug("plain")
          console("enc opened with the key on /dev/sda")
          booted()

      with subtest("PIN stick: wrong, then right"):
          boot()
          plug("withpin")
          console("PIN for enc")
          machine.send_console("0000\n")
          console("wrong PIN")
          console("PIN for enc")
          machine.send_console("1234\n")
          console("enc opened with the key on /dev/sda")
          booted()

      with subtest("PIN stick: empty PIN falls back to the passphrase"):
          boot()
          plug("withpin")
          console("PIN for enc")
          machine.send_console("\n")
          console("Please enter passphrase for disk")
          machine.send_console("pass\n")
          booted()

      with subtest("GPT stick"):
          boot()
          plug("gpt")
          console("enc opened with the key on /dev/sda")
          booted()

      with subtest("adopted stick"):
          boot()
          plug("legacy")
          console("enc opened with the key on /dev/sda")
          booted()
    '';
}
