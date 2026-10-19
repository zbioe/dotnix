{ lib, pkgs, ... }:
{
  imports = [
    ./hardware.nix
  ];

  # the login password as a hash in /persist, outside the (public) flake
  users.users.zbioe = {
    hashedPassword = lib.mkForce null;
    hashedPasswordFile = "/persist/secrets/zbioe.passwd";
  };

  modules = {
    host = {
      name = "bx";
    };
    keyboard = {
      layout = "us";
      model = "";
      variant = "intl";
    };
    snapshots = {
      enable = true;
      exclude = [
        {
          path = ".cache";
          keep = false;
        }
        { path = "Downloads"; }
      ];
    };
    # Proton Drive (`backup setup` once), see modules/backup.nix
    backup = {
      enable = true;
      exclude = [
        "Mail" # already on the mail server
        "bkp"
      ];
      # persisted and outside the snapshots (/ is wiped at boot)
      cacheDir = "/var/lib/nodatacow/backup";
    };
  };

  # a desktop (no battery): full speed always; amd-pstate is already active
  # (nixos-hardware common-cpu-amd-pstate)
  powerManagement.cpuFreqGovernor = "performance";

  services.xserver.videoDrivers = [ "amdgpu" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      rocmPackages.clr.icd # OpenCL para tarefas pesadas
    ];
  };

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/bluetooth"
      "/var/lib/bitcoin"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/etc/NetworkManager/system-connections"
      "/var/lib/systemd/resolved"
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
  services.ollama = {
    package = pkgs.ollama-rocm;
    rocmOverrideGfx = "11.0.0";
  };

  # DO NOT CHANGE IT
  system.stateVersion = "25.11";
}
