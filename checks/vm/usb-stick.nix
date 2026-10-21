{ pkgs, ... }:
let
  usbStick = pkgs.callPackage ../../pkgs/usb-stick { };

  # small NixOS ISOs that say when they booted; "official" lacks iso/findiso.nix, like the upstream ones
  nixosIso =
    name: extra:
    (pkgs.nixos (
      { modulesPath, lib, ... }:
      {
        imports = [ "${modulesPath}/installer/cd-dvd/iso-image.nix" ] ++ extra;
        image.baseName = lib.mkForce name;
        isoImage = {
          makeEfiBootable = true;
          makeUsbBootable = true;
          squashfsCompression = "zstd -Xcompression-level 1";
        };
        boot.kernelParams = [ "console=ttyS0,115200" ];
        boot.initrd.availableKernelModules = [
          "xhci_pci"
          "usb_storage"
          "sd_mod"
        ];
        systemd.services.booted = {
          wantedBy = [ "multi-user.target" ];
          serviceConfig.Type = "oneshot";
          script = "echo BOOTED-${name} > /dev/ttyS0";
        };
        documentation.enable = false;
        system.stateVersion = "26.05";
      }
    )).config.system.build.isoImage;
  oursIso = nixosIso "ours" [ ../../iso/findiso.nix ];
  officialIso = nixosIso "official" [ ];

  fakeIso =
    name: files:
    pkgs.runCommand "${name}.iso" { nativeBuildInputs = [ pkgs.xorriso ]; } ''
      mkdir -p root
      ${files}
      xorriso -as mkisofs -V ${name} -o $out root
    '';
  loopIso = fakeIso "linux-test" ''
    mkdir -p root/boot/grub
    echo 'echo "LOOPBACK-OK $iso_path"' > root/boot/grub/loopback.cfg
    echo 'sleep 600' >> root/boot/grub/loopback.cfg
  '';
  winIso = fakeIso "windows" "echo setup > root/setup.txt";

  ovmf = "${pkgs.OVMF.fd}/FV/OVMF.fd";
in
{
  name = "dotnix-usb-stick";

  nodes.machine = {
    virtualisation = {
      emptyDiskImages = [ 64 ];
      memorySize = 2048;
      qemu.options = [ "-device qemu-xhci,id=xhci" ];
    };
    environment.systemPackages = [
      usbStick
      pkgs.cryptsetup
    ];
  };

  testScript = ''
    import queue, re, time

    pending = {}

    # wait_for_console_text with a timeout reads one line a second: too slow for a boot log
    def console(m, text, timeout=300):
        deadline = time.monotonic() + timeout
        while True:
            try:
                while True:
                    pending[m.name] = pending.get(m.name, "") + m.last_lines.get(block=False) + "\n"
            except queue.Empty:
                pass
            found = re.search(text, pending.get(m.name, ""))
            if found:
                seen = pending[m.name][: found.end()]
                pending[m.name] = pending[m.name][found.end():]
                return seen
            if time.monotonic() > deadline:
                raise Exception(f"{text!r} not on the console of {m.name} after {timeout}s")
            time.sleep(0.1)

    image = machine.state_dir / "stick.img"
    with open(image, "wb") as f:
        f.truncate(6 << 30)

    machine.wait_for_unit("multi-user.target")
    machine.succeed("echo -n pass | cryptsetup luksFormat -q --pbkdf pbkdf2 --iter-time 1 /dev/vdb -")

    with subtest("a small stick without ISOs: only FILES and the key"):
        small = machine.state_dir / "small.img"
        with open(small, "wb") as f:
            f.truncate(3800 << 20)
        machine.send_monitor_command(f"drive_add 0 if=none,id=small,file={small},format=raw")
        machine.send_monitor_command("device_add usb-storage,id=dev-small,drive=small,bus=xhci.0")
        machine.wait_until_succeeds("test -b /dev/sda")
        out = machine.succeed("echo -n pass | usb-stick create --yes /dev/sda 2>&1")
        assert "opens /dev/vdb" in out, out
        labels = machine.succeed("lsblk -nro PARTLABEL /dev/sda").split()
        assert labels == ["FILES"], labels
        out = machine.fail("usb-stick list /dev/sda 2>&1")
        assert "no ISOS partition" in out, out
        machine.send_monitor_command("device_del dev-small")
        machine.wait_until_fails("test -b /dev/sda")

    with subtest("make the stick"):
        machine.send_monitor_command(f"drive_add 0 if=none,id=stick,file={image},format=raw")
        machine.send_monitor_command("device_add usb-storage,id=dev-stick,drive=stick,bus=xhci.0")
        machine.wait_until_succeeds("test -b /dev/sda")
        out = machine.succeed("echo -n pass | usb-stick create --yes --serial /dev/sda ${oursIso} ${loopIso} 2>&1")
        assert "opens /dev/vdb" in out, out
        out = machine.fail("usb-stick add /dev/sda ${winIso} 2>&1")
        assert "not a Linux ISO" in out, out
        out = machine.fail("usb-stick add /dev/sda ${officialIso} 2>&1")
        assert "upstream NixOS" in out, out
        machine.succeed("mkdir -p /m && mount /dev/sda3 /m && cp ${winIso} /m/isos/windows.iso && cp ${officialIso}/iso/official.iso /m/isos/ && umount /m")
        listing = machine.succeed("usb-stick list /dev/sda")
        assert "linux-test.iso" in listing and "ours.iso" in listing, listing
        assert "not supported (upstream NixOS)" in listing and "windows.iso" in listing, listing
        machine.succeed("sync")
        machine.send_monitor_command("device_del dev-stick")
        machine.shutdown()

    def boot_stick():
        stick = create_machine(
            "${pkgs.qemu_kvm}/bin/qemu-kvm -m 1536 -cpu max -bios ${ovmf}"
            " -device qemu-xhci,id=xhci"
            f" -drive if=none,id=stick,format=raw,file={image}"
            " -device usb-storage,drive=stick,bus=xhci.0,bootindex=1",
            name="stick",
        )
        pending.pop("stick", None)
        stick.start()
        return stick

    # the GRUB menu's ISO entries, in the order shown
    def menu(m):
        text = console(m, "Firmware setup")
        text = text[text.rfind("command-line.") :]
        entries, i = [], text.find("/isos/")
        while i >= 0:
            end = text.find(".iso", i) + len(".iso")
            if text[i:end] not in entries:
                entries.append(text[i:end])
            i = text.find("/isos/", end)
        return entries

    markers = {
        "/isos/linux-test.iso": "LOOPBACK-OK /isos/linux-test.iso",
        "/isos/ours.iso": "BOOTED-ours",
    }

    with subtest("the menu lists the folder, bootable ISOs first; the default entry boots"):
        stick = boot_stick()
        entries = menu(stick)
        assert sorted(entries[:2]) == sorted(markers), entries
        assert sorted(entries[2:]) == ["/isos/official.iso", "/isos/windows.iso"], entries
        console(stick, markers[entries[0]], timeout=600)
        stick.crash()

    with subtest("the other bootable ISO, picked with the arrows"):
        stick = boot_stick()
        entries = menu(stick)
        stick.send_key("down")
        stick.send_key("ret")
        console(stick, markers[entries[1]], timeout=600)
        stick.crash()
  '';
}
