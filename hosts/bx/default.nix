{ inputs, ... }:
{
  imports = [
    ../common.nix
    ./hardware-configuration.nix
    inputs.hardware.nixosModules.common-pc
    inputs.hardware.nixosModules.common-cpu-amd
    inputs.hardware.nixosModules.common-cpu-amd-pstate
    inputs.hardware.nixosModules.common-gpu-amd
    inputs.hardware.nixosModules.common-pc-ssd
  ];

  networking.hostName = "bx";

  dotnix = {
    hardware = {
      graphics.amd = {
        enable = true;
        compute.enable = true;
      };
      keyboard = {
        layout = "us";
        variant = "intl";
      };
    };
    storage = {
      disk = {
        enable = true;
        luks = "/dev/disk/by-uuid/8e7e951a-5b4c-4bfe-92f2-57d1f88da1d7";
        efi = "/dev/disk/by-uuid/12CE-A600";
        swap = "/dev/disk/by-partuuid/87f16c7f-16be-46da-ab99-db8f719b49a0";
      };
      impermanence.enable = true;
      usbKey.enable = true;
      snapshots = {
        enable = true;
        exclude = [
          {
            path = ".cache";
            keep = false;
          }
          { path = "Downloads"; }
          {
            path = ".local/share/docker";
            keep = false;
          }
        ];
      };
      # Proton Drive (`backup setup` once)
      backup = {
        enable = true;
        exclude = [
          "Mail" # already on the mail server
          "bkp"
          ".local/share/docker" # images and containers: rebuilt, not restored
        ];
        # persisted and outside the snapshots (/ is wiped at boot)
        cacheDir = "/var/lib/nodatacow/backup";
      };
    };
    services.ai.ollama.rocm = "11.0.0";
  };

  # a desktop (no battery): full speed always; amd-pstate is already active
  # (nixos-hardware common-cpu-amd-pstate)
  powerManagement.cpuFreqGovernor = "performance";

  # the MediaTek Wi-Fi drops out with PCIe power saving
  boot.extraModprobeConfig = ''
    options mt7921e disable_aspm=1
  '';

  # DO NOT CHANGE IT
  system.stateVersion = "25.11";
}
