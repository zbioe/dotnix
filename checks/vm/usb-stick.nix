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
          # and whether that was a Secure Boot one
          script = ''
            sb=$(od -An -t u1 /sys/firmware/efi/efivars/SecureBoot-* 2>/dev/null || true)
            echo "BOOTED-${name} SB=''${sb##* }" > /dev/ttyS0
          '';
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
    # (stays there: a key would go on)
    echo 'read' >> root/boot/grub/loopback.cfg
  '';
  winIso = fakeIso "windows" "echo setup > root/setup.txt";

  ovmf = "${pkgs.OVMF.fd}/FV/OVMF.fd";
  # with Secure Boot: its keys go into a copy of the variables
  ovmfSecure = pkgs.OVMFFull.fd;
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
      pkgs.sbctl
    ];
  };

  testScript = ''
    import queue, re, subprocess, time

    pending = {}

    # wait_for_console_text with a timeout reads one line a second: too slow for a boot log
    def console(m, text, timeout=300):
        deadline = time.monotonic() + timeout
        pending.setdefault(m.name, "")
        while not (found := re.search(text, pending[m.name])):
            left = deadline - time.monotonic()
            try:
                pending[m.name] += m.last_lines.get(timeout=max(left, 0)) + "\n"
            except queue.Empty:
                raise Exception(f"{text!r} not on the console of {m.name} after {timeout}s")
        seen = pending[m.name][: found.end()]
        pending[m.name] = pending[m.name][found.end():]
        return seen

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
        labels = machine.succeed("lsblk -nro LABEL /dev/sda").split()
        assert labels == ["FILES"], labels
        # what car radios read: MBR, FAT32
        table = machine.succeed("lsblk -dnro PTTYPE /dev/sda").strip()
        assert table == "dos", table
        out = machine.fail("usb-stick list /dev/sda 2>&1")
        assert "no ISOS partition" in out, out
        # made again with --keep-key: the same key, no new LUKS slot
        slots = "cryptsetup luksDump /dev/vdb | grep -c '^  [0-9]*: luks2'"
        before = machine.succeed(slots)
        out = machine.succeed("usb-stick create --keep-key --yes /dev/sda 2>&1")
        assert "Its key stays" in out and "opens /dev/vdb" in out, out
        assert machine.succeed(slots) == before
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

    with subtest("signed: systemd-boot and the NixOS ISO's UKI, with this machine's sbctl keys"):
        machine.start()
        machine.wait_for_unit("multi-user.target")
        machine.succeed("sbctl create-keys >&2")
        machine.send_monitor_command(f"drive_add 0 if=none,id=stick,file={image},format=raw")
        machine.send_monitor_command("device_add usb-storage,id=dev-stick,drive=stick,bus=xhci.0")
        machine.wait_until_succeeds("test -b /dev/sda")
        out = machine.succeed("usb-stick add /dev/sda ${oursIso} 2>&1")
        assert "systemd-boot: signed" in out and "ours.iso: signed" in out, out
        for k in ["PK/PK.pem", "KEK/KEK.pem", "db/db.pem", "../GUID"]:
            machine.copy_from_vm(f"/var/lib/sbctl/keys/{k}", "sbctl")
        machine.succeed("sync")
        machine.send_monitor_command("device_del dev-stick")
        machine.shutdown()

    with subtest("the NixOS ISO boots with Secure Boot on"):
        keys = machine.out_dir / "sbctl"
        guid = (keys / "GUID").read_text().strip()
        vars = machine.state_dir / "vars.fd"
        subprocess.run(
            ["${pkgs.python3Packages.virt-firmware}/bin/virt-fw-vars",
             "-i", "${ovmfSecure}/FV/OVMF_VARS.fd", "-o", str(vars),
             "--set-pk", guid, str(keys / "PK.pem"),
             "--add-kek", guid, str(keys / "KEK.pem"),
             "--add-db", guid, str(keys / "db.pem"),
             "--secure-boot"],
            check=True,
        )
        stick = create_machine(
            "${pkgs.qemu_kvm}/bin/qemu-kvm -m 1536 -cpu max -machine q35,smm=on"
            " -global driver=cfi.pflash01,property=secure,value=on"
            " -drive if=pflash,format=raw,unit=0,readonly=on,file=${ovmfSecure}/FV/OVMF_CODE.fd"
            f" -drive if=pflash,format=raw,unit=1,file={vars}"
            " -device qemu-xhci,id=xhci"
            f" -drive if=none,id=stick,format=raw,file={image}"
            " -device usb-storage,drive=stick,bus=xhci.0,bootindex=1",
            name="secure",
        )
        # systemd-boot's default: the first UKI
        stick.start()
        console(stick, "BOOTED-ours SB=1", timeout=600)
        stick.crash()
  '';
}
