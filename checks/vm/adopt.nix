# dotnix-adopt on a machine with the age key (bx), run while the new machine
# is still installing: its Secure Boot keys go to the live system, then, once
# the installed system is up (a new SSH host key), it comes into the flake
# (its hosts/<host>), that key opens secrets/, and that is committed and
# pushed (to a repository on bx here). The new machine then rebuilds itself
# from upstream (dotnix-firstboot.service; a flake that builds stand-ins).
{ inputs, dotlib }:
{ pkgs, lib, ... }:
let
  # dotnix-adopt and dotnix-sbctl-send as a host with secrets and Secure Boot
  # has them
  host = inputs.nixpkgs.lib.nixosSystem {
    inherit (pkgs.stdenv.hostPlatform) system;
    specialArgs = {
      inherit inputs dotlib;
      username = "zbioe";
    };
    modules = [
      inputs.impermanence.nixosModules.impermanence
      ../../system/core/boot.nix
      ../../system/core/secrets.nix
      ../../system/core/users.nix
      ../../system/storage/impermanence.nix
      {
        dotnix = {
          core.secrets.enable = true;
          core.boot = {
            enable = true;
            loader = "limine";
            secureBoot.enable = true;
          };
          storage.impermanence.enable = true;
        };
        fileSystems."/" = {
          device = "/dev/null";
          fsType = "ext4";
        };
        system.stateVersion = lib.trivial.release;
      }
    ];
  };
  tool = name: lib.findFirst (p: (p.name or "") == name) null host.config.environment.systemPackages;

  # your age key and SSH key (bx's), and a flake with secrets/ for them
  keys =
    pkgs.runCommand "test-keys"
      {
        nativeBuildInputs = with pkgs; [
          age
          openssh
        ];
      }
      ''
        mkdir $out
        age-keygen -o $out/age.txt 2>/dev/null
        ssh-keygen -q -t ed25519 -N "" -f $out/ssh
      '';
  # what the new machine's first rebuild builds: a system whose switch and a
  # home whose activation leave a trace
  flakeNix = pkgs.writeText "flake.nix" ''
    {
      outputs = _:
        let
          mk = name: script: derivation {
            inherit name;
            system = "${pkgs.stdenv.hostPlatform.system}";
            builder = "${pkgs.bash}/bin/bash";
            args = [ "-c" script ];
            PATH = "${pkgs.coreutils}/bin";
          };
        in
        {
          nixosConfigurations.new.config.system.build.toplevel = mk "toplevel"
            "mkdir -p $out/bin; printf '#!/bin/sh\\necho \"$1\" > /tmp/switched\\n' > $out/bin/switch-to-configuration; chmod +x $out/bin/switch-to-configuration";
          homeConfigurations.new.activationPackage = mk "home"
            "mkdir $out; printf '#!/bin/sh\\ntouch $HOME/activated\\n' > $out/activate; chmod +x $out/activate";
        };
    }
  '';
  flake = pkgs.runCommand "test-flake" { nativeBuildInputs = with pkgs; [ sops ]; } ''
    pub=$(grep -o 'age1.*' ${keys}/age.txt)
    mkdir -p $out/secrets $out/hosts/bx
    cp ${flakeNix} $out/flake.nix
    echo '{"nodes":{"root":{}},"root":"root","version":7}' > $out/flake.lock
    cat > $out/.sops.yaml <<EOF
    keys:
      - &zbioe $pub
    creation_rules:
      - path_regex: secrets/common\.yaml$
        key_groups:
          - age:
              - *zbioe
    EOF
    echo "wifi: secret" > common.yaml
    sops encrypt --age "$pub" --filename-override secrets/common.yaml common.yaml > $out/secrets/common.yaml
    echo "{ }" > $out/hosts/bx/default.nix
  '';
in
{
  name = "dotnix-adopt";

  node.specialArgs = {
    username = "zbioe";
    homeActivation = pkgs.writeTextFile {
      name = "home";
      destination = "/activate";
      executable = true;
      text = "#!/bin/sh\n";
    };
  };

  nodes = {
    bx = {
      environment.systemPackages = [
        (tool "dotnix-adopt")
        (tool "dotnix-sbctl-send")
        pkgs.git
        pkgs.sbctl
      ];
      users.users.zbioe = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        # the new machine fetches from here
        openssh.authorizedKeys.keyFiles = [ "${keys}/ssh.pub" ];
      };
      security.sudo.wheelNeedsPassword = false;
      services.openssh.enable = true;
      programs.ssh.extraConfig = "StrictHostKeyChecking accept-new";
    };
    new = {
      imports = [
        ../../system/core/users.nix
        ../../system/core/home-activation.nix
      ];
      networking.hostName = "new";
      dotnix.core.homeActivation.enable = true;
      services.openssh.enable = true;
      programs.ssh.extraConfig = "StrictHostKeyChecking accept-new";
      environment.systemPackages = with pkgs; [
        git
        sops
        ssh-to-age
      ];
      users.users.zbioe.openssh.authorizedKeys.keyFiles = [ "${keys}/ssh.pub" ];
      # the stand-ins build offline, from the store paths flake.nix names
      # (given to the sandbox: they aren't inputs there)
      nix.settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        extra-sandbox-paths = [
          "${pkgs.bash}"
          "${pkgs.coreutils}"
        ];
        substituters = lib.mkForce [ ];
      };
      system.extraDependencies = with pkgs; [
        bash
        coreutils
      ];
    };
  };

  testScript = ''
    start_all()
    new.wait_for_unit("sshd.service")
    bx.wait_for_unit("sshd.service")

    import shlex

    def as_zbioe(m, cmd):
        return m.succeed(f"su - zbioe -s /bin/sh -c {shlex.quote(cmd)}")

    # bx: the flake, its upstream, your keys, Secure Boot keys
    bx.succeed("install -d -o zbioe /srv/origin.git && su - zbioe -c 'git init -q --bare -b main /srv/origin.git'")
    as_zbioe(bx, "install -Dm600 ${keys}/age.txt .config/sops/age/keys.txt && install -Dm600 ${keys}/ssh .ssh/id_ed25519")
    as_zbioe(bx, "cp -r ${flake} dotnix && chmod -R u+w dotnix && cd dotnix && git init -q -b main && git add -A"
                 " && git -c user.name=t -c user.email=t@t commit -qm init && git remote add origin /srv/origin.git && git push -q -u origin main")
    as_zbioe(bx, "git config --global user.name t && git config --global user.email t@t")
    bx.succeed("sbctl create-keys >&2 && mkdir -p /persist/var/lib && cp -a /var/lib/sbctl /persist/var/lib/")

    # the new machine as dotnix-install leaves it: hosts/new, a checkout of
    # upstream with nothing committed, the firstboot marker
    as_zbioe(new, "install -Dm600 ${keys}/ssh .ssh/id_ed25519")
    as_zbioe(new, "mkdir -p dotnix/hosts/new && echo '{ networking.hostName = \"new\"; }' > dotnix/hosts/new/default.nix"
                  " && cd dotnix && git init -q -b main && git remote add origin zbioe@bx:/srv/origin.git && git add -A"
                  " && touch .git/dotnix-firstboot")
    # still the live system
    new.succeed("install -m755 /dev/null /run/wrappers/bin/dotnix-install")

    with subtest("firstboot waits for the host upstream"):
        new.succeed("systemctl start dotnix-firstboot.service")
        new.succeed("test -e /home/zbioe/dotnix/.git/dotnix-firstboot")
        new.fail("test -e /tmp/switched")

    with subtest("dotnix-adopt on the live system: the keys, then waits"):
        bx.succeed("systemd-run --unit adopt --uid zbioe -p WorkingDirectory=/home/zbioe --setenv=HOME=/home/zbioe --setenv=PATH=$PATH"
                   " sh -c 'echo y | dotnix-adopt new > /tmp/adopt.out 2>&1; echo $? > /tmp/adopt.rc'")
        new.wait_until_succeeds("tar -tf /tmp/dotnix-sbctl.tar | grep -q sbctl/keys/db/db.key")
        bx.wait_until_succeeds("grep -q 'waiting for it' /tmp/adopt.out")
        bx.fail("test -e /tmp/adopt.rc")
        # nothing of the live system's in known_hosts
        bx.fail("su - zbioe -c 'ssh-keygen -F new'")

    with subtest("the installed system boots: adopted and pushed"):
        new.succeed("rm /run/wrappers/bin/dotnix-install /etc/ssh/ssh_host_*")
        new.succeed("systemctl restart sshd-keygen.service || true; systemctl restart sshd.service")
        new.succeed("test -e /etc/ssh/ssh_host_ed25519_key")
        bx.wait_until_succeeds("test -e /tmp/adopt.rc", timeout=180)
        out = bx.succeed("cat /tmp/adopt.out")
        print(out)
        assert bx.succeed("cat /tmp/adopt.rc").strip() == "0", out
        upstream = as_zbioe(bx, "git -C /srv/origin.git show main:hosts/new/default.nix")
        assert "new" in upstream, upstream
        sops_yaml = as_zbioe(bx, "git -C /srv/origin.git show main:.sops.yaml")
        assert "&new age1" in sops_yaml and "- *new" in sops_yaml, sops_yaml
        assert as_zbioe(bx, "git -C /srv/origin.git log --format=%s -1").strip() == "add new"

    with subtest("the new machine opens secrets/ with its own SSH key"):
        as_zbioe(bx, "git -C /srv/origin.git show main:secrets/common.yaml > /tmp/common.yaml")
        bx.copy_from_vm("/tmp/common.yaml", "")
        new.copy_from_host(str(bx.out_dir / "common.yaml"), "/tmp/common.yaml")
        out = new.succeed("SOPS_AGE_KEY=$(ssh-to-age -private-key -i /etc/ssh/ssh_host_ed25519_key) sops -d /tmp/common.yaml")
        assert "wifi: secret" in out, out

    with subtest("firstboot: upstream, the system for the next boot, the home"):
        # a build sometimes killed (signal 9) on CI runners: again, as its timer does
        new.wait_until_succeeds("systemctl start dotnix-firstboot.service", timeout=120)
        assert new.succeed("cat /tmp/switched").strip() == "boot"
        new.succeed("test -e /home/zbioe/activated")
        new.fail("test -e /home/zbioe/dotnix/.git/dotnix-firstboot")
        head = as_zbioe(new, "git -C dotnix rev-parse HEAD")
        assert head == as_zbioe(bx, "git -C /srv/origin.git rev-parse main")
        # done: the marker gone, it doesn't run again
        new.succeed("rm /tmp/switched && systemctl start dotnix-firstboot.service")
        new.fail("test -e /tmp/switched")

    with subtest("a second time: refused"):
        bx.fail("su - zbioe -c 'echo y | dotnix-adopt new'")
  '';
}
