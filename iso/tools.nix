# Tools on both ISOs (minimal and full):
#   dotnix-install  partition a disk (modules/disk-layout.nix), create a host
#                   for this machine in the flake and install it
#   dotnix-mount    open and mount an installed disk on /mnt (recovery), then
#                   `nixos-enter` to work inside it
# plus what a recovery needs: disks, btrfs, LUKS, and restic/rclone to get
# files back from the backup (modules/backup.nix).
{
  lib,
  pkgs,
  ...
}:
let
  # the directories default/ bind-mounts from the nodatacow subvolume
  nodatacowDirs = [
    "docker"
    "flatpak"
    "waydroid"
    "cloudflare-warp"
    "bitcoind"
  ];

  mountAll = ''
    # subvolumes of modules/disk-layout.nix on /mnt
    mount_all() {
      local o=compress=zstd,noatime
      mount -o subvol=root,$o /dev/mapper/enc /mnt
      mkdir -p /mnt/{home,nix,persist,var/log,var/lib/nodatacow,boot}
      mount -o subvol=home,$o /dev/mapper/enc /mnt/home
      mount -o subvol=nix,$o /dev/mapper/enc /mnt/nix
      mount -o subvol=persist,$o /dev/mapper/enc /mnt/persist
      mount -o subvol=log,$o /dev/mapper/enc /mnt/var/log
      mount -o subvol=nodatacow,noatime /dev/mapper/enc /mnt/var/lib/nodatacow
      mount -o umask=0077 /dev/disk/by-partlabel/dotnix-efi /mnt/boot
    }
  '';

  install = pkgs.writeShellApplication {
    name = "dotnix-install";
    runtimeInputs = with pkgs; [
      coreutils
      util-linux
      gptfdisk
      cryptsetup
      btrfs-progs
      dosfstools
      e2fsprogs # chattr
      gnugrep
      gnused
      gawk
      systemd # udevadm
      nixos-install-tools
      nix
      mkpasswd
    ];
    text = ''
      bold=$'\e[1m' red=$'\e[31m' off=$'\e[0m'
      die() { echo "''${red}$*''${off}" >&2; exit 1; }
      ask() { local a; read -rp "$1 " a; echo "''${a:-$2}"; }

      [ "$(id -u)" = 0 ] || exec sudo "$0" "$@"
      [ -d /sys/firmware/efi ] || die "Boot this machine in UEFI mode (dotnix boots with GRUB EFI)."

      echo "''${bold}dotnix install''${off}: this setup on this machine. ''${red}The chosen disk is erased.''${off}"
      echo

      # the disks, without the one this ISO runs from
      live=$(lsblk -no PKNAME "$(findmnt -no SOURCE /iso 2>/dev/null || true)" 2>/dev/null || true)
      echo "Disks:"
      # (no loop devices, CD drives or zram swap)
      lsblk -dpno NAME,SIZE,MODEL,TRAN -e 7,11 | grep -v "^/dev/''${live:-none} \|^/dev/zram" | sed 's/^/  /'
      disk=$(ask "Disk to install on (e.g. /dev/nvme0n1):" "")
      [ -b "$disk" ] || die "not a disk: $disk"
      [ "$disk" != "/dev/$live" ] || die "that is the USB this ISO runs from"

      host=$(ask "Name of this machine [dotnix]:" dotnix)
      [[ $host =~ ^[a-z][a-z0-9-]*$ ]] || die "use lowercase letters, digits and -"
      [ ! -e "/etc/dotnix/hosts/$host" ] || die "hosts/$host already exists in the flake, pick another name"

      echo
      echo "Root filesystem:"
      echo "  1) impermanence, like bx: / is wiped at every boot, state in /persist (default)"
      echo "  2) persistent: / keeps what is written to it"
      case $(ask "Choice [1]:" 1) in
        2) impermanence=false ;;
        *) impermanence=true ;;
      esac

      ram=$(awk '/MemTotal/ { printf "%d", $2 / 1048576 + 0.5 }' /proc/meminfo)
      swap=$(ask "Swap in GiB [$ram]:" "$ram")
      [[ $swap =~ ^[0-9]+$ ]] || die "not a number: $swap"

      while :; do
        read -rsp "Disk encryption password: " pw; echo
        read -rsp "Again: " pw2; echo
        [ -n "$pw" ] && [ "$pw" = "$pw2" ] && break
        echo "''${red}empty or different, again''${off}"
      done
      while :; do
        read -rsp "Password of zbioe (empty keeps the default, weakPass): " upw; echo
        [ -z "$upw" ] && break
        read -rsp "Again: " upw2; echo
        [ "$upw" = "$upw2" ] && break
        echo "''${red}different, again''${off}"
      done

      echo
      echo "''${bold}$disk''${off} ($(lsblk -dno SIZE "$disk")) will be ''${red}erased''${off}: host $host, impermanence $impermanence, swap ''${swap}G"
      [ "$(ask "Type the disk path again to go on:" "")" = "$disk" ] || die "cancelled"

      # the live session's heavy services, out of the way of nix (the live
      # system lives in RAM; evaluating the flake alone takes some GB)
      systemctl stop ollama open-webui docker.socket docker waydroid-container 2>/dev/null || true

      set -x
      swapoff /dev/disk/by-partlabel/dotnix-swap 2>/dev/null || true
      umount -R /mnt 2>/dev/null || true
      cryptsetup close enc 2>/dev/null || true

      sgdisk --zap-all "$disk"
      sgdisk --new=1::+1G --typecode=1:ef00 --change-name=1:dotnix-efi \
        --new=2::+"$swap"G --typecode=2:8200 --change-name=2:dotnix-swap \
        --new=3::0 --typecode=3:8309 --change-name=3:dotnix-luks "$disk"
      udevadm settle
      sleep 1
      efi=/dev/disk/by-partlabel/dotnix-efi
      luks=/dev/disk/by-partlabel/dotnix-luks

      mkfs.vfat -F 32 -n BOOT "$efi"
      mkswap -L swap /dev/disk/by-partlabel/dotnix-swap
      # room for the install: the live system runs from RAM
      swapon /dev/disk/by-partlabel/dotnix-swap
      printf '%s' "$pw" | cryptsetup -q luksFormat --type luks2 --label dotnix "$luks" --key-file=-
      printf '%s' "$pw" | cryptsetup open "$luks" enc --key-file=-
      unset pw pw2
      mkfs.btrfs -f -L dotnix /dev/mapper/enc

      mkdir -p /mnt
      mount /dev/mapper/enc /mnt
      for sub in root home nix persist log nodatacow; do btrfs subvolume create "/mnt/$sub"; done
      chattr +C /mnt/nodatacow
      mkdir -p ${lib.concatMapStringsSep " " (d: "/mnt/nodatacow/${d}") nodatacowDirs}
      if [ "$impermanence" = true ]; then btrfs subvolume snapshot -r /mnt/root /mnt/root-blank; fi
      umount /mnt

      ${mountAll}
      mount_all

      # the flake, with a host for this machine, in the user's home
      flake=/mnt/home/zbioe/dotnix
      mkdir -p "$flake"
      cp -r /etc/dotnix/. "$flake"
      chmod -R u+w "$flake"
      mkdir -p "$flake/hosts/$host"
      nixos-generate-config --root /mnt --no-filesystems --show-hardware-config 2>/dev/null > "$flake/hosts/$host/hardware.nix"
      # the login password as a hash in /persist, outside the flake
      passwd=""
      if [ -n "$upw" ]; then
        mkdir -p /mnt/persist/secrets
        printf '%s' "$upw" | mkpasswd -m yescrypt -s > /mnt/persist/secrets/zbioe.passwd
        chmod 600 /mnt/persist/secrets/zbioe.passwd
        passwd='
        # hash written by dotnix-install (outside the flake)
        users.users.zbioe = {
          hashedPassword = lib.mkForce null;
          hashedPasswordFile = "/persist/secrets/zbioe.passwd";
        };'
      fi
      unset upw upw2
      cat > "$flake/hosts/$host/default.nix" <<EOF
      # $host: installed by dotnix-install on $(date +%F) (iso/tools.nix)
      { lib, ... }:
      {
        imports = [ ./hardware.nix ];
      $passwd

        modules = {
          host.name = "$host";
          disk = {
            enable = true;
            impermanence = $impermanence;
          };
          snapshots.enable = true;
          # Proton Drive backup: \`backup setup\` once
          backup = {
            enable = true;
            cacheDir = "/var/lib/nodatacow/backup";
          };
        };

        # the release it was installed with; do not change
        system.stateVersion = "${lib.trivial.release}";
      }
      EOF
      chown -R 1000:100 /mnt/home/zbioe

      # everything is already in this ISO's store: no download needed
      nixos-install --flake "path:$flake#$host" --no-root-passwd --no-channel-copy
      set +x

      echo
      echo "''${bold}Done.''${off} Remove the USB and reboot. The flake is in ~/dotnix (hosts/$host);"
      echo "make it a git checkout again with: git -C ~/dotnix init && git -C ~/dotnix add -A"
      echo "Then: backup setup (and restore your files from it), nh home switch -c $host."
    '';
  };

  mount = pkgs.writeShellApplication {
    name = "dotnix-mount";
    runtimeInputs = with pkgs; [
      coreutils
      util-linux
      cryptsetup
      btrfs-progs
      nixos-install-tools
    ];
    text = ''
      [ "$(id -u)" = 0 ] || exec sudo "$0" "$@"
      luks=''${1:-/dev/disk/by-partlabel/dotnix-luks}
      [ -b "$luks" ] || {
        echo "no $luks; pass the LUKS partition: dotnix-mount /dev/nvme0n1p3"
        exit 1
      }
      [ -e /dev/mapper/enc ] || cryptsetup open "$luks" enc
      mkdir -p /mnt
      ${mountAll}
      mount_all
      echo "mounted on /mnt; a shell inside the installed system: nixos-enter --root /mnt"
    '';
  };
in
{
  environment.systemPackages = with pkgs; [
    install
    mount
    git
    gptfdisk
    cryptsetup
    btrfs-progs
    restic
    rclone
  ];
}
