# dotnix-adopt on a machine with the age key (bx): a machine dotnix-install
# made comes into the flake (its hosts/<host>), its SSH host key opens
# secrets/, and that is committed and pushed (to a local repository here).
{ inputs, dotlib }:
{ pkgs, lib, ... }:
let
  # dotnix-adopt as a host with secrets has it
  host = inputs.nixpkgs.lib.nixosSystem {
    inherit (pkgs.stdenv.hostPlatform) system;
    specialArgs = {
      inherit inputs dotlib;
      username = "zbioe";
    };
    modules = [
      ../../system/core/secrets.nix
      ../../system/core/users.nix
      {
        dotnix.core.secrets.enable = true;
        fileSystems."/" = {
          device = "/dev/null";
          fsType = "ext4";
        };
        system.stateVersion = lib.trivial.release;
      }
    ];
  };
  adopt = lib.findFirst (
    p: (p.name or "") == "dotnix-adopt"
  ) null host.config.environment.systemPackages;

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
  flake = pkgs.runCommand "test-flake" { nativeBuildInputs = with pkgs; [ sops ]; } ''
    pub=$(grep -o 'age1.*' ${keys}/age.txt)
    mkdir -p $out/secrets $out/hosts/bx
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

  nodes = {
    bx = {
      environment.systemPackages = [
        adopt
        pkgs.git
      ];
      users.users.zbioe.isNormalUser = true;
      programs.ssh.extraConfig = "StrictHostKeyChecking accept-new";
    };
    new = {
      networking.hostName = "new";
      services.openssh.enable = true;
      environment.systemPackages = with pkgs; [
        sops
        ssh-to-age
      ];
      users.users.zbioe = {
        isNormalUser = true;
        openssh.authorizedKeys.keyFiles = [ "${keys}/ssh.pub" ];
      };
    };
  };

  testScript = ''
    start_all()
    new.wait_for_unit("sshd.service")
    bx.wait_for_unit("multi-user.target")

    import shlex

    def as_zbioe(m, cmd):
        return m.succeed(f"su - zbioe -c {shlex.quote(cmd)}")

    # what dotnix-install left on the new machine
    as_zbioe(new, "mkdir -p dotnix/hosts/new && echo '{ networking.hostName = \"new\"; }' > dotnix/hosts/new/default.nix")

    # bx: the flake, its upstream, your keys
    bx.succeed("install -d -o zbioe /srv/origin.git && su - zbioe -c 'git init -q --bare -b main /srv/origin.git'")
    as_zbioe(bx, "install -Dm600 ${keys}/age.txt .config/sops/age/keys.txt && install -Dm600 ${keys}/ssh .ssh/id_ed25519")
    as_zbioe(bx, "cp -r ${flake} dotnix && chmod -R u+w dotnix && cd dotnix && git init -q -b main && git add -A"
                 " && git -c user.name=t -c user.email=t@t commit -qm init && git remote add origin /srv/origin.git && git push -q -u origin main")
    as_zbioe(bx, "git config --global user.name t && git config --global user.email t@t")

    with subtest("dotnix-adopt brings it in and pushes"):
        status, out = bx.execute("su - zbioe -c 'echo y | dotnix-adopt new 2>&1'")
        print(out)
        assert status == 0, out
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

    with subtest("a second time: refused"):
        bx.fail("su - zbioe -c 'echo y | dotnix-adopt new'")
  '';
}
