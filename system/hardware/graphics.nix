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
      initrdFirmware = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        example = [ "yellow_carp_*" ];
        description = ''
          The amdgpu firmware files (shell patterns) the initrd keeps; null
          keeps all of them, ~38M for every AMD GPU. The ones this GPU loads
          show up in `dmesg` when booted with
          `dyndbg="file drivers/base/firmware_loader/main.c +p"`. The
          system keeps them all.
        '';
      };
      # DCN 3.1 (Radeon 660M/680M): a refresh rate or rotation change that
      # grows the compressed buffer can hang the display, flickering until
      # the cable is plugged again
      compbufFix.enable = lib.mkEnableOption ''
        the kernel's wait for the display buffers to resize before the
        compressed buffer grows (an RFC fix, not merged yet); it needs
        dotnix.core.boot.fastKernel, whose workflow builds the kernel'';
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

    # upstream since 7.3 (7.3.4 has it, the patch no longer applies)
    boot.kernelPatches =
      lib.optional
        (cfg.amd.compbufFix.enable && lib.versionOlder config.dotnix.core.boot.kernel.kernel.version "7.3")
        {
          name = "amdgpu-compbuf-det-wait";
          patch = ./patches/amdgpu-compbuf-det-wait.patch;
        };

    services.xserver.videoDrivers = mkIf (drivers != [ ]) drivers;

    # the initrd's modules and firmware as NixOS builds them (stage-1.nix),
    # from a firmware tree without the other GPUs' amdgpu files: the
    # bootloader reads the whole initrd before Linux starts
    system.build.modulesClosure = mkIf (cfg.amd.initrdFirmware != null) (
      lib.mkForce (
        pkgs.makeModulesClosure {
          rootModules = config.boot.initrd.availableKernelModules ++ config.boot.initrd.kernelModules;
          kernel = config.system.modulesTree;
          firmware = pkgs.runCommand "initrd-firmware" { } ''
            mkdir $out
            # links to each file, through the linked folders
            cp -rLs ${config.hardware.firmware}/lib $out/
            chmod -R u+w $out
            for f in $out/lib/firmware/amdgpu/*; do
              case "$(basename "$f")" in
                ${lib.concatStringsSep "|" cfg.amd.initrdFirmware}) ;;
                *) rm "$f" ;;
              esac
            done
          '';
          allowMissing = config.boot.initrd.allowMissingModules;
          inherit (config.boot.initrd) extraFirmwarePaths;
        }
      )
    );

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

    assertions = [
      {
        assertion = cfg.amd.compbufFix.enable -> config.dotnix.core.boot.fastKernel.enable;
        message = "dotnix.hardware.graphics.amd.compbufFix needs dotnix.core.boot.fastKernel (built by CI, never here)";
      }
    ]
    ++ lib.optionals cfg.nvidia.enable [
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
