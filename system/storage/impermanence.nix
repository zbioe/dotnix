# / goes back to the empty root-blank at every boot: only /persist, /home,
# /nix and /var/log keep state
{
  config,
  lib,
  ...
}:
{
  options.dotnix.storage.impermanence.enable = lib.mkEnableOption "a root reset at every boot";

  config = lib.mkIf config.dotnix.storage.impermanence.enable {
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
        "/etc/NetworkManager/system-connections"
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
