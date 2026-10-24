# On both ISOs: dotnix-install (a disk and a host for this machine),
# dotnix-mount (recovery) and the tools a recovery needs.
{
  lib,
  pkgs,
  username,
  ...
}:
let
  mountAll = ''
    # subvolumes of system/storage/disk.nix on /mnt
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
      cryptsetup
      gnugrep
      gnused
      gawk
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
        read -rsp "Password of ${username} (empty keeps the default, weakPass): " upw; echo
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

      # the flake, with a host for this machine (its disk: system/storage/disk.nix)
      flake=/tmp/dotnix
      rm -rf "$flake"
      cp -r /etc/dotnix/. "$flake"
      chmod -R u+w "$flake"
      mkdir -p "$flake/hosts/$host"
      # a stable name for the disk, as the host will know it
      for id in /dev/disk/by-id/*; do
        [[ $id == *-part* || $id == */nvme-eui.* || $id == */wwn-* ]] && continue
        [ "$(readlink -f "$id")" = "$(readlink -f "$disk")" ] && { disk=$id; break; }
      done

      set -x
      swapoff /dev/disk/by-partlabel/dotnix-swap 2>/dev/null || true
      umount -R /mnt 2>/dev/null || true
      cryptsetup close enc 2>/dev/null || true

      # the login password as a hash in /persist, outside the flake; none keeps weakPass
      password="core.user.passwordFile = null;" passwd=""
      if [ -n "$upw" ]; then
        passwd=$(printf '%s' "$upw" | mkpasswd -m yescrypt -s)
        # over the secrets/ one, which a new host can't decrypt yet
        password="core.user.passwordFile = \"/persist/secrets/${username}.passwd\";"
      fi
      unset upw upw2
      # generated once the disk is mounted
      echo "{ }" > "$flake/hosts/$host/hardware-configuration.nix"
      cat > "$flake/hosts/$host/default.nix" <<EOF
      # $host: installed by dotnix-install on $(date +%F)
      {
        imports = [
          ../common.nix
          ./hardware-configuration.nix
        ];

        networking.hostName = "$host";

        dotnix = {
          $password
          # its home, the first time (then \`nh home switch\`)
          core.homeActivation.enable = true;
          hardware.keyboard.layout = "br";
          storage = {
            disk = {
              enable = true;
              device = "$disk";
              swapSize = "''${swap}G";
            };
            impermanence.enable = $impermanence;
            snapshots.enable = true;
            # Proton Drive: \`backup setup\` once
            backup = {
              enable = true;
              cacheDir = "/var/lib/nodatacow/backup";
            };
          };
        };

        # the release it was installed with; do not change
        system.stateVersion = "${lib.trivial.release}";
      }
      EOF

      # erase, partition, encrypt and mount on /mnt
      ( umask 077; printf '%s' "$pw" > /tmp/dotnix-luks.key )
      unset pw pw2
      format=$(nix build --no-link --print-out-paths "path:$flake#nixosConfigurations.$host.config.system.build.destroyFormatMount")
      "$format/bin/disko-destroy-format-mount" --yes-wipe-all-disks
      shred -u /tmp/dotnix-luks.key
      # room for the install: the live system runs from RAM
      mkswap /dev/disk/by-partlabel/dotnix-swap
      swapon /dev/disk/by-partlabel/dotnix-swap

      nixos-generate-config --root /mnt --no-filesystems --show-hardware-config 2>/dev/null > "$flake/hosts/$host/hardware-configuration.nix"
      if [ -n "$passwd" ]; then
        mkdir -p /mnt/persist/secrets
        printf '%s\n' "$passwd" > /mnt/persist/secrets/${username}.passwd
        chmod 600 /mnt/persist/secrets/${username}.passwd
      fi
      mkdir -p /mnt/home/${username}
      mv "$flake" /mnt/home/${username}/dotnix
      flake=/mnt/home/${username}/dotnix
      chown -R 1000:100 /mnt/home/${username}

      # offline: what the host needs is in this ISO's store (iso/live.nix), even
      # what's marked to be built locally (wrappers, small files)
      nixos-install --flake "path:$flake#$host" --no-root-passwd --no-channel-copy \
        --option always-allow-substitutes true
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
    (callPackage ../pkgs/dotnix-key { })
    btrfs-progs
    restic
    rclone
  ];
}
