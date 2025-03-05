{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) types mkOption mkIf;
  cfg = config.modules.nvidia;
in
{
  options.modules.nvidia = with types; {
    enable = mkOption {
      type = bool;
      default = false;
      description = ''
        Enable sound support.
      '';
    };
    amdgpuBusId = mkOption {
      type = str;
      default = "";
      example = "PCI:0:0:0";
      description = ''
        Bus ID for the AMD GPU. If intel is disabled
        See it with:
        nix shell nixpkgs#pciutils -c lspci | grep 'VGA'
      '';
    };
    intelBusId = mkOption {
      type = str;
      default = "";
      example = "PCI:0:0:0";
      description = ''
        Bus ID for the Intel GPU. If amd is disabled
        See it with:
        nix shell nixpkgs#pciutils -c lspci | grep 'VGA'
      '';
    };
    nvidiaBusId = mkOption {
      type = str;
      default = "";
      example = "PCI:0:0:0";
      description = ''
        Bus ID for the Nvidia GPU.
        See it with:
        nix shell nixpkgs#pciutils -c lspci | grep 'VGA'
      '';
    };
  };
  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.amdgpuBusId != "" || cfg.intelBusId != "";
        message = "amdgpuBusId or intelBusId need to be set. Can't be empty";
      }
      {
        assertion = cfg.amdgpuBusId == "" || cfg.intelBusId == "";
        message = "pick one, amdgpuBusId or intelBusId to set. Can't be both";
      }
      {
        assertion = cfg.nvidiaBusId != "";
        message = "nvidiaBusId need to be set";
      }
    ];
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      # https://discourse.nixos.org/t/nvidia-565-77-wont-work-in-kernel-6-13/59234/9
      package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
        version = "570.86.16"; # use new 570 drivers
        sha256_64bit = "sha256-RWPqS7ZUJH9JEAWlfHLGdqrNlavhaR1xMyzs8lJhy9U=";
        openSha256 = "sha256-DuVNA63+pJ8IB7Tw2gM4HbwlOh1bcDg2AN2mbEU9VPE=";
        settingsSha256 = "sha256-9rtqh64TyhDF5fFAYiWl3oDHzKJqyOW3abpcf2iNRT8=";
        usePersistenced = false;
      };

      # Modesetting is required.
      modesetting.enable = true;

      # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
      powerManagement.enable = false;
      # Fine-grained power management. Turns off GPU when not in use.
      # Experimental and only works on modern Nvidia GPUs (Turing or newer).
      powerManagement.finegrained = false;

      # Use the NVidia open source kernel module (not to be confused with the
      # independent third-party "nouveau" open source driver).
      # Support is limited to the Turing and later architectures. Full list of
      # supported GPUs is at:
      # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
      # Only available from driver 515.43.04+
      # Currently alpha-quality/buggy, so false is currently the recommended setting.
      open = false;

      # Enable the Nvidia settings menu,
      # accessible via `nvidia-settings`.
      nvidiaSettings = true;

      # Optionally, you may need to select the appropriate driver version for your specific GPU.
      # package = config.boot.kernelPackages.nvidiaPackages.stable;

      # nix shell nixpkgs#pciutils -c lspci | grep 'VGA'
      prime = {
        # SYNC mode
        sync.enable = true;

        # Offload mode
        offload = {
          enable = false;
          enableOffloadCmd = false;
        };

        inherit (cfg) intelBusId;
        inherit (cfg) nvidiaBusId;
        inherit (cfg) amdgpuBusId;
      };

    };
  };
}
