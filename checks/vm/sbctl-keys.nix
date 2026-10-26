# Where dotnix-install takes the Secure Boot keys from (dotnix-sbctl-keys):
# another machine sending them over SSH (dotnix-sbctl-send), that machine's
# backup (a local restic server standing in for Proton Drive), or new ones.
{
  inputs,
  dotlib,
  unstable,
}:
{ pkgs, lib, ... }:
let
  # dotnix-sbctl-send as a host with secureBoot has it
  host = inputs.nixpkgs.lib.nixosSystem {
    inherit (pkgs.stdenv.hostPlatform) system;
    specialArgs = {
      inherit dotlib unstable;
      username = "zbioe";
    };
    modules = [
      inputs.impermanence.nixosModules.impermanence
      ../../system/core/boot.nix
      ../../system/core/users.nix
      ../../system/storage/impermanence.nix
      {
        dotnix.core.boot = {
          enable = true;
          loader = "limine";
          secureBoot.enable = true;
        };
        fileSystems."/" = {
          device = "/dev/null";
          fsType = "ext4";
        };
        system.stateVersion = lib.trivial.release;
      }
    ];
  };
  send = lib.findFirst (
    p: (p.name or "") == "dotnix-sbctl-send"
  ) null host.config.environment.systemPackages;

  # the sender's SSH key, which the live system takes (as hosts/common.nix's)
  sshKey = pkgs.runCommand "test-ssh-key" { nativeBuildInputs = [ pkgs.openssh ]; } ''
    mkdir $out
    ssh-keygen -q -t ed25519 -N "" -f $out/key
  '';
in
{
  name = "dotnix-sbctl-keys";

  node.specialArgs.username = "zbioe";

  nodes = {
    bx = {
      environment.systemPackages = [
        send
        pkgs.sbctl
        pkgs.restic
      ];
      system.activationScripts.sshKey = "install -Dm600 ${sshKey}/key /root/.ssh/id_ed25519";
      programs.ssh.extraConfig = "StrictHostKeyChecking accept-new";
      # its backup, as Proton Drive would hold it
      services.restic.server = {
        enable = true;
        extraFlags = [ "--no-auth" ];
      };
      networking.firewall.allowedTCPPorts = [ 8000 ];
    };
    live = {
      imports = [ ../../iso/tools.nix ];
      services.openssh.enable = true;
      users.users.zbioe = {
        isNormalUser = true;
        openssh.authorizedKeys.keyFiles = [ "${sshKey}/key.pub" ];
      };
    };
  };

  testScript = ''
    start_all()
    bx.wait_for_unit("multi-user.target")
    live.wait_for_unit("sshd.service")
    bx.succeed("sbctl create-keys >&2")
    db = bx.succeed("cat /var/lib/sbctl/keys/db/db.pem")

    def same_keys():
        assert live.succeed("cat /var/lib/sbctl/keys/db/db.pem") == db
        live.succeed("test -f /var/lib/sbctl/keys/PK/PK.key -a -f /var/lib/sbctl/GUID")

    with subtest("over SSH, sent before choosing"):
        bx.succeed("dotnix-sbctl-send live >&2")
        live.succeed("dotnix-sbctl-keys ssh < /dev/null >&2")
        same_keys()
        live.fail("test -e /tmp/dotnix-sbctl.tar")

    with subtest("over SSH, sent while it waits"):
        live.succeed("rm -rf /var/lib/sbctl")
        # (in a unit of its own: the test waits for a command's output to close)
        live.succeed("systemd-run --unit keys-wait --setenv=PATH=$PATH sh -c 'dotnix-sbctl-keys ssh < /dev/null > /tmp/out 2>&1; echo $? > /tmp/rc'")
        live.wait_until_succeeds("grep -q Waiting /tmp/out")
        bx.succeed("dotnix-sbctl-send live >&2")
        live.wait_until_succeeds("test -e /tmp/rc")
        assert live.succeed("cat /tmp/rc").strip() == "0", live.succeed("cat /tmp/out")
        same_keys()

    with subtest("from the other machine's backup"):
        bx.succeed("mkdir -p /persist/.backup/var/lib && cp -a /var/lib/sbctl /persist/.backup/var/lib/")
        bx.wait_for_unit("restic-rest-server.socket")
        bx.succeed("export RESTIC_PASSWORD=pw RESTIC_REPOSITORY=rest:http://localhost:8000/bx; restic init && restic backup --host bx /persist/.backup >&2")
        env = "RESTIC_REPOSITORY=rest:http://bx:8000/bx"
        live.fail(f"{env} RESTIC_PASSWORD=wrong dotnix-sbctl-keys backup bx < /dev/null >&2")
        live.succeed(f"{env} RESTIC_PASSWORD=pw dotnix-sbctl-keys backup bx < /dev/null >&2")
        same_keys()

    with subtest("new keys"):
        live.succeed("dotnix-sbctl-keys new >&2")
        assert live.succeed("cat /var/lib/sbctl/keys/db/db.pem") != db
  '';
}
