# The daily backup and its restore test (system/storage/backup.nix), with a
# local folder standing in for Proton Drive (an rclone alias) and the secrets
# in the user's keyring: the restore test reads the Secure Boot keys back and
# fails when they aren't the ones in /persist.
{ pkgs, lib, ... }:
{
  name = "dotnix-backup";

  node.specialArgs.username = "zbioe";

  nodes.machine = {
    imports = [
      ../../system/storage/backup.nix
      ../../system/core/users.nix
    ];
    # what backup.nix reads from system/core/boot.nix and impermanence.nix
    options.dotnix = {
      core.boot.secureBoot.enable = lib.mkOption { default = true; };
      storage.impermanence.enable = lib.mkOption { default = true; };
    };
    config = {
      dotnix.storage.backup = {
        enable = true;
        subvolumes = [ "/persist" ];
      };
      boot.supportedFilesystems = [ "btrfs" ];
      virtualisation.emptyDiskImages = [ 2048 ];
      virtualisation.fileSystems."/persist" = {
        device = "/dev/vdb";
        fsType = "btrfs";
        autoFormat = true;
      };
      services.gnome.gnome-keyring.enable = true;
      environment.systemPackages = [ pkgs.libsecret ];
      # a session bus without logging in
      users.users.zbioe.linger = true;
    };
  };

  testScript = ''
    import shlex

    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("user@1000.service")

    def as_zbioe(cmd):
        env = "export XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus; "
        return machine.succeed(f"su - zbioe -s /bin/sh -c {shlex.quote(env + cmd)}")

    # what `backup setup` leaves: the keyring's secrets, the remote, the repository
    as_zbioe("echo -n login | gnome-keyring-daemon --replace --unlock --components=secrets --daemonize")
    as_zbioe("printf pw | secret-tool store --label restic service dotnix-backup key restic")
    as_zbioe("printf rc | secret-tool store --label rclone service dotnix-backup key rclone")
    machine.succeed("install -d -o zbioe /srv/backup")
    as_zbioe("mkdir -p .config/rclone && printf '[proton]\\ntype = alias\\nremote = /srv/backup\\n' > .config/rclone/rclone.conf")
    as_zbioe("backup restic init")

    machine.succeed(
        "for k in PK KEK db; do mkdir -p /persist/var/lib/sbctl/keys/$k && head -c 64 /dev/urandom > /persist/var/lib/sbctl/keys/$k/$k.key; done",
        "mkdir -p /persist/data && for i in $(seq 50); do head -c 4096 /dev/urandom > /persist/data/$i; done",
    )

    with subtest("a backup"):
        machine.succeed("systemctl start backup@now.service")
        out = as_zbioe("backup snapshots")
        print(out)
        assert "/persist/.backup" in out, out

    with subtest("the restore test, the keys among what it reads back"):
        machine.succeed("systemctl start backup@verify-now.service")
        result = machine.succeed("cat /var/cache/backup/last-verify-result")
        assert result.startswith("ok"), result

    with subtest("keys that changed since the backup fail it"):
        machine.succeed("head -c 64 /dev/urandom > /persist/var/lib/sbctl/keys/db/db.key")
        machine.fail("systemctl start backup@verify-now.service")
        result = machine.succeed("cat /var/cache/backup/last-verify-result")
        assert result.startswith("failed sbctl"), result
        # the next backup has them
        machine.succeed("systemctl start backup@now.service")
        machine.succeed("systemctl start backup@verify-now.service")
        assert machine.succeed("cat /var/cache/backup/last-verify-result").startswith("ok")
  '';
}
