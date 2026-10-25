# The boot splash on screen with Limine: Plymouth asks for the disk password
# over the theme picked with `theme` (theme-boot leaves its name on the ESP,
# desktop.bootScreens), read off the screen as the background's color.
{ inputs, dotlib }:
{ pkgs, lib, ... }:
let
  target = inputs.nixpkgs.lib.nixosSystem {
    inherit (pkgs.stdenv.hostPlatform) system;
    specialArgs = {
      inherit dotlib;
      inherit (inputs) base16;
      username = "zbioe";
    };
    modules = [
      inputs.disko.nixosModules.disko
      inputs.impermanence.nixosModules.impermanence
      ../../system/core/boot.nix
      ../../system/storage/disk.nix
      ../../system/storage/impermanence.nix
      ../../system/core/users.nix
      ../../system/desktop/boot-screens.nix
      "${inputs.nixpkgs}/nixos/modules/profiles/qemu-guest.nix"
      "${inputs.nixpkgs}/nixos/modules/testing/test-instrumentation.nix"
      {
        dotnix = {
          core.boot = {
            enable = true;
            loader = "limine";
          };
          storage = {
            disk = {
              enable = true;
              device = "/dev/vda";
              swapSize = "256M";
            };
            impermanence.enable = true;
          };
          desktop.bootScreens.enable = true;
        };
        # the splash on the screen, though the test reads the serial console
        boot.kernelParams = [ "plymouth.ignore-serial-consoles" ];
        boot.initrd.kernelModules = [ "bochs" ];
        boot.consoleLogLevel = lib.mkForce 7;
        boot.binfmt.emulatedSystems = lib.mkForce [ ];
        documentation.enable = false;
        system.stateVersion = lib.trivial.release;
      }
    ];
  };
  inherit (target.config.system.build) toplevel destroyFormatMount;
in
{
  name = "dotnix-boot-splash";

  nodes = {
    installer = {
      virtualisation = {
        # the target's disk is vda; the installer runs from vdb
        diskImage = "./target.qcow2";
        diskSize = 8 * 1024;
        emptyDiskImages = [ 1024 ];
        rootDevice = "/dev/vdb";
        memorySize = 2048;
        additionalPaths = [ toplevel ];
        fileSystems."/".autoFormat = true;
      };
      imports = [ "${inputs.nixpkgs}/nixos/tests/common/auto-format-root-device.nix" ];
      environment.systemPackages = [ pkgs.cryptsetup ];
      nix.settings.substituters = lib.mkForce [ ];
    };
    target = {
      virtualisation = {
        diskImage = "./target.qcow2";
        memorySize = 2048;
        useBootLoader = true;
        useEFIBoot = true;
        efi.keepVariables = false;
        useDefaultFilesystems = false;
        fileSystems."/" = {
          device = "/dev/disk/by-label/unused";
          fsType = "ext4";
        };
      };
    };
  };

  testScript = ''
    import time
    from collections import Counter

    installer.start()
    installer.wait_for_unit("multi-user.target")
    installer.succeed("udevadm settle")
    installer.succeed("printf secret > /tmp/dotnix-luks.key")
    installer.succeed("${destroyFormatMount}/bin/disko-destroy-format-mount --yes-wipe-all-disks >&2")
    installer.succeed("nixos-install --system ${toplevel} --no-root-passwd --no-channel-copy >&2")
    installer.succeed("umount -R /mnt && cryptsetup close enc && sync")
    installer.shutdown()

    target.state_dir = installer.state_dir

    def background():
        # the screen's most common color, from a raw screendump (P6)
        shot = target.state_dir / "screen.ppm"
        target.send_monitor_command(f"screendump {shot}")
        data = shot.read_bytes()
        magic, width, height, depth, pixels = data.split(maxsplit=4)
        assert magic == b"P6" and depth == b"255"
        rgb = Counter(bytes(pixels[i:i + 3]) for i in range(0, len(pixels) - 2, 3 * 97))
        return "#" + rgb.most_common(1)[0][0].hex()

    def boot(color):
        target.start()
        # the splash, then its password prompt over it
        want = bytes.fromhex(color[1:])
        # (the framebuffer rounds a channel or two)
        def close(seen):
            return all(abs(a - b) <= 4 for a, b in zip(bytes.fromhex(seen[1:]), want))
        deadline = time.time() + 120
        while not close(seen := background()):
            assert time.time() < deadline, f"background {seen}, not {color}"
            time.sleep(1)
        target.screenshot("splash-" + color[1:])
        time.sleep(3)
        target.send_chars("secret\n")
        target.wait_for_unit("multi-user.target")

    with subtest("the default theme's splash"):
        boot("#282828")
        target.succeed("install -d -o zbioe /home/zbioe/.local/state/theme")
        target.succeed("echo catppuccin-light > /home/zbioe/.local/state/theme/boot")
        target.succeed("systemctl start theme-boot.service")
        target.shutdown()

    with subtest("the one picked"):
        boot("#eff1f5")
        target.shutdown()
  '';
}
