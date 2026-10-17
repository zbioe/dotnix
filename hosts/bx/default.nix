{ pkgs, ... }:
{
  imports = [
    ./hardware.nix
  ];

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

  # force deep sleep
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "performance";

      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 1;

      CPU_DRIVER_OPMODE_ON_AC = "active";
      CPU_DRIVER_OPMODE_ON_BAT = "active";

      USB_EXCLUDE_BTUSB = 1;

      # DEVICES_TO_DISABLE_ON_STARTUP = "bluetooth";
    };
  };

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
