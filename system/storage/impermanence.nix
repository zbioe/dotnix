# / goes back to the empty root-blank at every boot: only /persist, /home,
# /nix and /var/log keep state
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # what was written to / since boot (newer than root-blank): lost on the next
  # one; caches and temporary files only with -a
  diff = pkgs.writeShellApplication {
    name = "dotnix-diff";
    runtimeInputs = with pkgs; [
      coreutils
      util-linux
      btrfs-progs
      gnugrep
      gawk
    ];
    text = ''
      [ "$(id -u)" = 0 ] || exec sudo "$0" "$@"
      skip='^(tmp|var/tmp|var/cache)/'
      [ "''${1:-}" = -a ] && skip='^$'
      mnt=$(mktemp -d)
      trap 'umount "$mnt"; rmdir "$mnt"' EXIT
      mount -o subvolid=5,ro /dev/mapper/enc "$mnt"
      gen=$(btrfs subvolume find-new "$mnt/root-blank" 9999999 | awk '{ print $NF }')
      # inode N file offset N len N disk start N offset N gen N flags F <path>
      btrfs subvolume find-new "$mnt/root" "$gen" | grep '^inode' | cut -d' ' -f17- |
        grep -Ev "$skip" | sort -u | while read -r path; do
          # (still there, and not what NixOS links again at boot)
          [ -e "/$path" ] || continue
          [[ $(readlink "/$path") =~ ^/(nix/store|etc/static)/ ]] && continue
          echo "/$path"
        done || true
    '';
  };
in
{
  options.dotnix.storage.impermanence.enable = lib.mkEnableOption "a root reset at every boot";

  config = lib.mkIf config.dotnix.storage.impermanence.enable {
    environment.systemPackages = [ diff ];

    boot.initrd.systemd.services.rollback = {
      description = "Reset the btrfs root subvolume to root-blank";
      wantedBy = [ "initrd.target" ];
      after = [ "systemd-cryptsetup@enc.service" ];
      before = [ "sysroot.mount" ];
      unitConfig.DefaultDependencies = "no";
      serviceConfig.Type = "oneshot";
      script = ''
        mkdir -p /mnt
        mount -o subvolid=5 /dev/mapper/enc /mnt
        delete() {
          for sub in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
            delete "/mnt/$sub"
          done
          btrfs subvolume delete "$1"
        }
        if [ -e /mnt/root-blank ]; then
          [ -d /mnt/root ] && delete /mnt/root
          btrfs subvolume snapshot /mnt/root-blank /mnt/root
        else
          echo "rollback: no root-blank, / is kept"
        fi
        umount /mnt
      '';
    };

    environment.persistence."/persist" = {
      hideMounts = true;
      directories = [
        "/var/lib/bluetooth"
        "/var/lib/nixos"
        "/var/lib/systemd/coredump"
        "/var/lib/systemd/resolved"
        # Wi-Fi and Bluetooth left off stay off
        "/var/lib/systemd/rfkill"
        "/etc/NetworkManager/system-connections"
        # its secret key (stable per-network addresses), leases, networks seen
        "/var/lib/NetworkManager"
        # firmware updates waiting for the next boot
        "/var/lib/fwupd"
      ];
      files = [
        "/etc/hosts"
        "/etc/machine-id"
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_ed25519_key.pub"
        "/etc/ssh/ssh_host_rsa_key"
        "/etc/ssh/ssh_host_rsa_key.pub"
      ];
    };
  };
}
