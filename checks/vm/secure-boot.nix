# Secure Boot and TPM2 on a VM, as the README has them: a host installed with
# Limine boots in Setup Mode, its first rebuild with secureBoot makes the keys
# (in /persist) and enrolls them, the next boot is a Secure Boot one, and
# after dotnix-tpm2-enroll the disk opens with the PIN. The boot theme, with
# the command line sealed, comes from the ESP (desktop.bootScreens).
{ inputs, dotlib }:
{ pkgs, lib, ... }:
let
  base = inputs.nixpkgs.lib.nixosSystem {
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
          desktop.bootScreens.enable = true;
        };
        # the prompts on the console the test reads
        boot.kernelParams = [ "console=ttyS0" ];
        boot.binfmt.emulatedSystems = lib.mkForce [ ];
        boot.consoleLogLevel = lib.mkForce 7;
        documentation.enable = false;
        system.stateVersion = lib.trivial.release;
      }
    ];
  };
  secure = base.extendModules {
    modules = [
      {
        dotnix.core.boot = {
          secureBoot.enable = true;
          tpm2.enable = true;
        };
      }
    ];
  };
  # the rebuild the host makes, already in its store
  target = base.extendModules {
    modules = [ { system.extraDependencies = [ secure.config.system.build.toplevel ]; } ];
  };
  inherit (target.config.system.build) toplevel destroyFormatMount;
  secureSystem = secure.config.system.build.toplevel;
in
{
  name = "dotnix-secure-boot";

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
        # Setup Mode until the host enrolls its keys
        useSecureBoot = true;
        efi.OVMF = pkgs.OVMFFull.fd;
        efi.keepVariables = false;
        tpm.enable = true;
        useDefaultFilesystems = false;
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
    installer.succeed("${destroyFormatMount}/bin/disko-destroy-format-mount --yes-wipe-all-disks >&2")
    installer.succeed("nixos-install --system ${toplevel} --no-root-passwd --no-channel-copy >&2")
    installer.succeed("umount -R /mnt && cryptsetup close enc && sync")
    installer.shutdown()

    target.state_dir = installer.state_dir

    def boot(prompt="passphrase for", answer="secret"):
        target.start()
        target.wait_for_console_text(prompt)
        target.send_console(answer + "\n")
        target.wait_for_unit("multi-user.target")

    def secure_boot():
        return target.succeed("od -An -t u1 /sys/firmware/efi/efivars/SecureBoot-*").split()[-1] == "1"

    with subtest("Limine, Setup Mode"):
        boot()
        target.succeed("test -e /boot/limine/limine.conf")
        assert not secure_boot()

    with subtest("the rebuild with secureBoot makes and enrolls the keys"):
        # what `nixos-rebuild boot` does
        target.succeed("nix-env -p /nix/var/nix/profiles/system --set ${secureSystem}")
        target.succeed("${secureSystem}/bin/switch-to-configuration boot >&2")
        target.succeed("test -e /persist/var/lib/sbctl/keys/db/db.key")
        target.fail("test -e /var/lib/sbctl")
        # not while Secure Boot is off (PCR 7 changes once it's on)
        target.fail("${secureSystem}/sw/bin/dotnix-tpm2-enroll < /dev/null")
        target.shutdown()

    with subtest("a Secure Boot boot, the keys kept"):
        boot()
        assert secure_boot()
        assert target.succeed("readlink -f /run/current-system").strip() == "${secureSystem}"
        target.succeed("test -e /persist/var/lib/sbctl/keys/db/db.key")
        # what dotnix-firstboot does: asks, then only once
        target.succeed("echo y | PASSWORD=secret NEWPIN=4321 dotnix-tpm2-enroll --offer >&2")
        target.succeed("dotnix-tpm2-enroll --offer < /dev/null")
        target.succeed("cryptsetup luksDump /dev/disk/by-partlabel/dotnix-luks | grep -q systemd-tpm2")
        assert target.succeed("cat /run/dotnix/boot-theme").strip() == "gruvbox-dark"
        # `theme` picks another one: theme-boot leaves it on the ESP
        target.succeed("install -d -o zbioe /home/zbioe/.local/state/theme")
        target.succeed("echo catppuccin-light > /home/zbioe/.local/state/theme/boot")
        target.succeed("systemctl start theme-boot.service")
        assert target.succeed("cat /boot/dotnix-theme").strip() == "catppuccin-light"
        target.shutdown()

    with subtest("the TPM opens the disk with the PIN, in the theme picked"):
        boot("PIN", "4321")
        assert secure_boot()
        assert target.succeed("cat /run/dotnix/boot-theme").strip() == "catppuccin-light"
        # anything else on the ESP: the default
        # (theme-boot would put the user's back)
        target.succeed("systemctl stop theme-boot.path")
        target.succeed("echo '../../bin/sh' > /boot/dotnix-theme && sync")
        target.shutdown()

    with subtest("a name Nix didn't build is ignored"):
        boot("PIN", "4321")
        assert target.succeed("cat /run/dotnix/boot-theme").strip() == "gruvbox-dark"
        target.shutdown()
  '';
}
