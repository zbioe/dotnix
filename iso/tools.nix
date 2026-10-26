# On both ISOs: dotnix-install (a disk and a host for this machine),
# dotnix-mount (recovery) and the tools a recovery needs.
{
  lib,
  pkgs,
  username,
  ...
}:
let
  # (enrolls on firmware that leaves its empty keys in place)
  sbctl = pkgs.callPackage ../pkgs/sbctl { };
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

  # Secure Boot keys for this machine, in /var/lib/sbctl: another machine's,
  # sent over SSH (dotnix-sbctl-send there) or from its backup, or new ones
  keys = pkgs.writeShellApplication {
    name = "dotnix-sbctl-keys";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      gnutar
      inotify-tools
      iproute2
      rclone
      restic
      sbctl
    ];
    text = ''
      [ "$(id -u)" = 0 ] || exec sudo "$0" "$@"
      usage() { echo "usage: dotnix-sbctl-keys ssh | backup HOST | new" >&2; exit 2; }

      from_ssh() {
        # (sent already, before choosing, is fine too)
        echo "On the machine with the keys run: dotnix-adopt ADDRESS (or dotnix-sbctl-send), one of"
        ip -4 -o addr show scope global | awk '{ split($4, a, "/"); print "  " a[1] }'
        echo "Waiting for them (Enter: give up)..."
        # dotnix-sbctl-send moves it in whole; watched before looking, so it
        # can't land in between
        local fd watch giveup="" name=""
        exec {fd}< <(exec inotifywait -m -e moved_to --format %f /tmp 2>&1)
        watch=$!
        until [ "$name" = "Watches established." ]; do read -r name <&"$fd"; done
        if [ ! -s /tmp/dotnix-sbctl.tar ]; then
          if [ -t 0 ]; then
            # (<&0: not /dev/null, as for any other background job)
            { read -r; kill "$watch"; } <&0 &
            giveup=$!
          fi
          while read -r name <&"$fd"; do
            [ "$name" != dotnix-sbctl.tar ] || break
          done
          [ -z "$giveup" ] || kill "$giveup" 2>/dev/null || true
        fi
        kill "$watch" 2>/dev/null || true
        exec {fd}<&-
        [ -s /tmp/dotnix-sbctl.tar ] || return 1
        tar -C /var/lib -xf /tmp/dotnix-sbctl.tar
        shred -u /tmp/dotnix-sbctl.tar
      }

      # system/storage/backup.nix's repository of that host; RESTIC_REPOSITORY
      # (and RESTIC_PASSWORD) set beforehand pick another one
      from_backup() {
        local src=$1 u p code mp args
        if [ -z "''${RESTIC_REPOSITORY:-}" ]; then
          export RCLONE_CONFIG=/tmp/dotnix-rclone.conf
          # (the Proton login: gone however this ends)
          trap 'rm -f /tmp/dotnix-rclone.conf' EXIT
          echo "Proton Drive login"
          read -rp "Proton e-mail: " u
          read -rsp "Password: " p; echo
          read -rp "2FA code (empty if none): " code
          read -rsp "Mailbox password (empty unless two-password mode): " mp; echo
          args=(username "$u" password "$p")
          [ -z "$code" ] || args+=(2fa "$code")
          [ -z "$mp" ] || args+=(mailbox_password "$mp")
          rclone config create proton protondrive "''${args[@]}" >/dev/null || return 1
          unset p mp
          export RESTIC_REPOSITORY="rclone:proton:dotnix-backup/$src"
        fi
        if [ -z "''${RESTIC_PASSWORD:-}" ]; then
          read -rsp "Backup password of $src (\`backup password\` there, or Proton Pass): " RESTIC_PASSWORD; echo
          export RESTIC_PASSWORD
        fi
        rm -rf /tmp/dotnix-restore
        restic restore latest --host "$src" --include /persist/.backup/var/lib/sbctl \
          --target /tmp/dotnix-restore || return 1
        cp -a /tmp/dotnix-restore/persist/.backup/var/lib/sbctl /var/lib/
        rm -rf /tmp/dotnix-restore /tmp/dotnix-rclone.conf
      }

      rm -rf /var/lib/sbctl
      mkdir -p /var/lib
      case ''${1:-} in
        ssh) from_ssh ;;
        backup) [ -n "''${2:-}" ] || usage; from_backup "$2" ;;
        new) sbctl create-keys >/dev/null ;;
        *) usage ;;
      esac
      [ -f /var/lib/sbctl/keys/db/db.key ] || { echo "no keys came" >&2; exit 1; }
      echo "keys in /var/lib/sbctl"
    '';
  };

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
      git
      sbctl
      keys
      nixos-facter
      jq
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

      # Secure Boot, with the firmware in Setup Mode (its keys cleared): keys
      # in the live /var/lib/sbctl (dotnix-sbctl-keys), then on the new disk;
      # enrolled at the end
      setup_mode() {
        local v
        v=$(od -An -t u1 /sys/firmware/efi/efivars/SetupMode-8be4df61-93ca-11d2-aa0d-00e098032b8c 2>/dev/null || true)
        [ "''${v##* }" = 1 ]
      }
      secure=false
      if setup_mode; then
        echo
        echo "Secure Boot (the firmware is in Setup Mode), with:"
        echo "  1) the keys of another machine, over SSH: one set everywhere, a signed stick boots on all (default)"
        echo "  2) the keys of another machine, from its backup (Proton Drive)"
        echo "  3) new keys, for this machine only"
        echo "  4) no Secure Boot"
        choice=$(ask "Choice [1]:" 1)
        case $choice in
          2) dotnix-sbctl-keys backup "$(ask "Machine whose backup has them [bx]:" bx)" || true ;;
          3) dotnix-sbctl-keys new || true ;;
          4) ;;
          *) dotnix-sbctl-keys ssh || true ;;
        esac
        if [ -f /var/lib/sbctl/keys/db/db.key ]; then
          secure=true
        elif [ "$choice" != 4 ]; then
          echo "''${red}no keys: installing without Secure Boot''${off}"
        fi
      fi

      # what this machine has (nixos-facter), without serial numbers (the
      # flake is public): hosts/<host>/facter.json, which lib/facter.nix turns
      # into kernel modules, firmware and nixos-hardware's modules from the
      # first rebuild on (the ISO carries a host without them)
      nixos-facter -o /tmp/dotnix-facter.json 2>/dev/null
      facts=$(jq 'walk(if type == "object" then del(.serial, .uuid, .asset_tag) else . end)' /tmp/dotnix-facter.json)
      rm -f /tmp/dotnix-facter.json
      hw=$(jq -r '[(.hardware.cpu[0].vendor_name // empty), (.hardware.graphics_card[]?.vendor.name),
        (.smbios.chassis[0].chassis_type.name // empty)] | join(", ")' <<<"$facts")
      echo
      echo "Hardware: $hw"
      [ "$secure" = false ] || echo "Secure Boot: Limine, signed with the keys of /var/lib/sbctl"
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
      secureboot=""
      if [ "$secure" = true ]; then
        secureboot="core.boot = { loader = \"limine\"; secureBoot.enable = true; };"
        # a TPM 2.0: the disk opens with it and a PIN too (dotnix-firstboot
        # enrolls it, once Secure Boot is on)
        if [ "$(cat /sys/class/tpm/tpm0/tpm_version_major 2>/dev/null)" = 2 ]; then
          secureboot="core.boot = { loader = \"limine\"; secureBoot.enable = true; tpm2.enable = true; };"
        fi
      fi
      # generated once the disk is mounted
      echo "{ }" > "$flake/hosts/$host/hardware-configuration.nix"
      echo "{ }" > "$flake/hosts/$host/hardware.nix"
      cat > "$flake/hosts/$host/default.nix" <<EOF
      # $host: installed by dotnix-install on $(date +%F)
      {
        imports = [
          ../common.nix
          ./hardware-configuration.nix
          ./hardware.nix
        ];

        networking.hostName = "$host";

        dotnix = {
          $password
          $secureboot
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

      # the keys first: Limine is signed while installing
      if [ "$secure" = true ]; then
        if [ "$impermanence" = true ]; then keys=/mnt/persist/var/lib; else keys=/mnt/var/lib; fi
        mkdir -p "$keys"
        cp -a /var/lib/sbctl "$keys/"
        chmod 700 "$keys/sbctl"
      fi

      nixos-generate-config --root /mnt --no-filesystems --show-hardware-config 2>/dev/null > "$flake/hosts/$host/hardware-configuration.nix"
      if [ -n "$passwd" ]; then
        mkdir -p /mnt/persist/secrets
        printf '%s\n' "$passwd" > /mnt/persist/secrets/${username}.passwd
        chmod 600 /mnt/persist/secrets/${username}.passwd
      fi
      mkdir -p /mnt/home/${username}
      mv "$flake" /mnt/home/${username}/dotnix
      flake=/mnt/home/${username}/dotnix

      # offline: what the host needs is in this ISO's store (iso/live.nix), even
      # what's marked to be built locally (wrappers, small files)
      nixos-install --flake "path:$flake#$host" --no-root-passwd --no-channel-copy \
        --option always-allow-substitutes true

      printf '%s\n' "$facts" > "$flake/hosts/$host/facter.json"
      cat > "$flake/hosts/$host/hardware.nix" <<EOF
      # what nixos-facter found here (facter.json; serial numbers left out)
      { dotlib, ... }:
      {
        imports = [ (dotlib.facter ./facter.json) ];
      }
      EOF
      # a checkout again (/etc/dotnix is a store copy): offline, nothing fetched yet
      git -C "$flake" init -q -b main
      git -C "$flake" remote add origin https://github.com/zbioe/dotnix.git
      git -C "$flake" add -A
      # the first rebuild, by itself once online (system/core/home-activation.nix)
      touch "$flake/.git/dotnix-firstboot"
      chown -R 1000:100 /mnt/home/${username}

      # last: once the firmware has keys it may refuse this unsigned ISO
      if [ "$secure" = true ] && setup_mode; then
        sbctl enroll-keys --microsoft || echo "''${red}the firmware didn't take the keys: sbctl enroll-keys --microsoft once booted''${off}"
      fi
      set +x

      echo
      echo "''${bold}Done.''${off} Remove the USB and reboot. The flake is in ~/dotnix (hosts/$host);"
      echo "Once it boots, online:"
      echo "  1. on a machine with your age key (bx): dotnix-adopt ADDRESS-OF-$host, unless"
      echo "     it is running already (hosts/$host and its key for secrets/, pushed)"
      echo "  2. here, nothing: the first rebuild runs by itself once hosts/$host is upstream"
      echo "     (with hosts/$host/hardware.nix: $hw), then asks for a reboot;"
      echo "     dotnix-firstboot does it right away"
      echo "  3. backup setup, and restore your files from it"
      if [ "$secure" = true ]; then
        echo "Secure Boot: turn it on in the firmware setup now (the keys are enrolled)."
      else
        echo "Secure Boot: see README (Secure Boot and TPM); the firmware needs Setup Mode."
      fi
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
    keys
    git
    gptfdisk
    cryptsetup
    (callPackage ../pkgs/dotnix-key { })
    btrfs-progs
    restic
    rclone
  ];
}
