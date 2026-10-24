# secrets/*.yaml (sops), decrypted at boot into /run/secrets: by the host's SSH
# key, or by your own age key that dotnix-install leaves on a new host
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.dotnix.core.secrets;

  # a host into .sops.yaml and secrets/common.yaml: this one, or another
  # through its SSH address (from a machine with your age key)
  enroll = pkgs.writeShellApplication {
    name = "dotnix-enroll";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      gnused
      gawk
      openssh
      ssh-to-age
      sops
    ];
    text = ''
      host=''${1:-$(uname -n)}
      flake=''${NH_FLAKE:-$HOME/dotnix}
      cd "$flake"
      [ -f .sops.yaml ] || { echo "no $flake/.sops.yaml (NH_FLAKE)" >&2; exit 1; }
      [ -f "''${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}" ] || {
        echo "no age key here: run it where it is, e.g. dotnix-enroll $host <address of $host>" >&2
        exit 1
      }

      if [ $# -ge 2 ]; then
        key=$(ssh-keyscan -q -t ed25519 "$2" | ssh-to-age)
      else
        key=$(ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub)
      fi
      [[ $key == age1* ]] || { echo "no ed25519 host key for $host" >&2; exit 1; }

      if grep -q "&$host " .sops.yaml; then
        # a reinstall: new key, same anchor
        sed -i "s|&$host age1.*|\&$host $key|" .sops.yaml
      else
        awk -v host="$host" -v key="$key" '
          /^  - &/ { last = NR }
          { line[NR] = $0 }
          END {
            for (i = 1; i <= NR; i++) {
              print line[i]
              if (i == last) print "  - &" host " " key
              if (rule && line[i] ~ /^          - \*/ && line[i + 1] !~ /^          - \*/) {
                print "          - *" host
                rule = 0
              }
              if (index(line[i], "secrets/common")) rule = 1
            }
          }
        ' .sops.yaml > .sops.yaml.new
        mv .sops.yaml.new .sops.yaml
      fi
      sops updatekeys -y secrets/common.yaml
      echo "$host opens secrets/common.yaml now; rebuild it to use them."
      grep -q 'passwordFile = "/persist/secrets/' "hosts/$host/default.nix" 2>/dev/null &&
        echo "Its login password then comes from secrets/ once hosts/$host drops core.user.passwordFile."
      true
    '';
  };
in
{
  imports = [ inputs.sops.nixosModules.sops ];

  options.dotnix.core.secrets = {
    enable = lib.mkEnableOption "the secrets of secrets/ (sops-nix)";
    keyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/persist/var/lib/sops/age.key";
      description = "Your age key on this host (it must exist); without it, only the SSH host key.";
    };
  };

  config = lib.mkIf cfg.enable {
    sops = {
      defaultSopsFile = ../../secrets/common.yaml;
      # read before impermanence binds /etc/ssh
      age.sshKeyPaths = [ "/persist/etc/ssh/ssh_host_ed25519_key" ];
      age.keyFile = cfg.keyFile;
      gnupg.sshKeyPaths = [ ];
      secrets.user-password.neededForUsers = true;
    };
    dotnix.core.user.passwordFile = lib.mkDefault config.sops.secrets.user-password.path;
    environment.systemPackages = [ enroll ];
  };
}
