{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotnix.hardware.graphics;
  drivers = lib.optional cfg.amd.enable "amdgpu" ++ lib.optional cfg.nvidia.enable "nvidia";
  inherit (lib) mkIf mkOption types;
  busId = mkOption {
    type = types.str;
    default = "";
    example = "PCI:1:0:0";
    description = "From `lspci | grep VGA`.";
  };
in
{
  options.dotnix.hardware.graphics = {
    enable = lib.mkEnableOption "graphics (32-bit too, for Steam and Wine)";
    amd = {
      enable = lib.mkEnableOption "AMD GPUs";
      compute.enable = lib.mkEnableOption "OpenCL on AMD (ROCm)";
    };
    nvidia = {
      enable = lib.mkEnableOption "NVIDIA GPUs (proprietary driver)";
      open = lib.mkEnableOption "NVIDIA's open kernel module (Turing and newer)";
      # PRIME sync between the integrated GPU and the NVIDIA one
      prime = {
        amdgpuBusId = busId;
        intelBusId = busId;
        nvidiaBusId = busId;
      };
    };
  };

  config = mkIf cfg.enable {
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = lib.optional cfg.amd.compute.enable pkgs.rocmPackages.clr.icd;
    };

    services.xserver.videoDrivers = mkIf (drivers != [ ]) drivers;

    hardware.nvidia = mkIf cfg.nvidia.enable {
      modesetting.enable = true;
      powerManagement.enable = false;
      powerManagement.finegrained = false;
      inherit (cfg.nvidia) open;
      nvidiaSettings = true;
      prime = {
        sync.enable = true;
        offload = {
          enable = false;
          enableOffloadCmd = false;
        };
        inherit (cfg.nvidia.prime) amdgpuBusId intelBusId nvidiaBusId;
      };
    };

    assertions = lib.optionals cfg.nvidia.enable [
      {
        assertion = (cfg.nvidia.prime.amdgpuBusId != "") != (cfg.nvidia.prime.intelBusId != "");
        message = "dotnix.hardware.graphics.nvidia.prime: set amdgpuBusId or intelBusId, not both";
      }
      {
        assertion = cfg.nvidia.prime.nvidiaBusId != "";
        message = "dotnix.hardware.graphics.nvidia.prime.nvidiaBusId is not set";
      }
    ];
  };
}
