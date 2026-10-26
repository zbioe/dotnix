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

  # a machine dotnix-install made (booted, its SSH up), into this flake: its
  # hosts/<host>, its SSH host key into secrets/ (dotnix-enroll), committed;
  # pushed if you say so, and it rebuilds itself from upstream. Run while it
  # is still installing (the live system), it sends the Secure Boot keys
  # first (dotnix-sbctl-send) and waits for the installed system to boot.
  user = config.dotnix.core.user.name;
  adopt = pkgs.writeShellApplication {
    name = "dotnix-adopt";
    runtimeInputs = with pkgs; [
      coreutils
      openssh
      git
      enroll
    ];
    text = ''
      # --wait: how long the installed system may be gone after the live one
      wait=20
      if [ "''${1:-}" = --wait ]; then
        [[ ''${2:-} =~ ^[0-9]+$ ]] || { echo "--wait takes minutes" >&2; exit 2; }
        wait=$2
        shift 2
      fi
      [ $# = 1 ] || { echo "usage: dotnix-adopt [--wait MINUTES] ADDRESS (of a machine dotnix-install made)" >&2; exit 2; }
      flake=''${NH_FLAKE:-$HOME/dotnix}
      cd "$flake"
      if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "$flake has changes: commit them first" >&2
        exit 1
      fi
      # the live system's SSH host key isn't the installed one's: kept out of
      # known_hosts, and the installed system is up once the key changes
      live=$(mktemp)
      trap 'rm -f "$live"' EXIT
      if ssh -n -o UserKnownHostsFile="$live" "${user}@$1" 'command -v dotnix-install' >/dev/null 2>&1; then
        if command -v dotnix-sbctl-send >/dev/null; then
          dotnix-sbctl-send -o UserKnownHostsFile="$live" "$1" || echo "Secure Boot keys not sent"
        fi
        echo "$1 is installing: waiting for it to boot the installed system..."
        key=$(ssh-keyscan -q -t ed25519 "$1" 2>/dev/null)
        # gone that long after the live system: it came back elsewhere
        # (another address from DHCP) or not at all. (Asked every 10 s: it
        # has no way to tell this machine it's up.)
        gone=""
        until k=$(ssh-keyscan -q -t ed25519 "$1" 2>/dev/null) && [ -n "$k" ] && [ "$k" != "$key" ]; do
          if [ -n "$k" ]; then gone=""; else gone=''${gone:-$SECONDS}; fi
          if [ -n "$gone" ] && [ $((SECONDS - gone)) -ge $((wait * 60)) ]; then
            echo "nothing at $1 for $wait minutes: once it is up, dotnix-adopt ITS-ADDRESS" >&2
            exit 1
          fi
          sleep 10
        done
        # its sshd may answer before the user can log in
        for _ in $(seq 30); do
          ssh -n -o ConnectTimeout=5 "${user}@$1" true 2>/dev/null && break
          sleep 5
        done
      fi
      host=$(ssh -n "${user}@$1" uname -n)
      [[ $host =~ ^[a-z][a-z0-9-]*$ ]] || { echo "not a host name: $host" >&2; exit 1; }
      [ ! -e "hosts/$host" ] || { echo "hosts/$host is here already" >&2; exit 1; }
      scp -rq "${user}@$1:dotnix/hosts/$host" hosts/
      dotnix-enroll "$host" "$1"
      git add "hosts/$host" .sops.yaml secrets/common.yaml
      git commit -qm "add $host"
      read -rp "Push it? [y/N] " a
      if [ "$a" = y ]; then
        git push -q
        echo "$host rebuilds itself from it within minutes (or dotnix-firstboot there)"
      else
        echo "After git push $host rebuilds itself from it (or dotnix-firstboot there)"
      fi
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
    environment.systemPackages = [
      enroll
      adopt
    ];
  };
}
