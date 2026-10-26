# A host's hardware from its nixos-facter report (hosts/<host>/facter.json,
# written by dotnix-install): nixpkgs' facter modules (kernel modules,
# microcode, firmware, graphics, bluetooth) and the nixos-hardware ones for
# its CPU, GPU and form factor. SSDs need nothing: fstrim is on by default.
{ lib }:
report:
{ config, inputs, ... }:
let
  facts = lib.importJSON report;
  hw = facts.hardware or { };
  cpus = map (c: c.vendor_name or "") (hw.cpu or [ ]);
  gpus = map (g: g.vendor.hex or "") (hw.graphics_card or [ ]);
  # SMBIOS chassis types of a portable machine (laptop, notebook, convertible...)
  portable = [
    8
    9
    10
    14
    30
    31
    32
  ];
  laptop = lib.any (c: lib.elem (c.chassis_type.value or 0) portable) (facts.smbios.chassis or [ ]);
  amdCpu = lib.elem "AuthenticAMD" cpus;
  intelCpu = lib.elem "GenuineIntel" cpus;
  amdGpu = lib.elem "1002" gpus;
  modules =
    lib.optionals amdCpu [
      "common-cpu-amd"
      "common-cpu-amd-pstate"
    ]
    ++ lib.optional intelCpu "common-cpu-intel"
    ++ lib.optional amdGpu "common-gpu-amd"
    # (common-cpu-intel brings it too)
    ++ lib.optional (lib.elem "8086" gpus && !intelCpu) "common-gpu-intel"
    ++ [ (if laptop then "common-pc-laptop" else "common-pc") ];
in
{
  imports = map (m: inputs.hardware.nixosModules.${m}) modules;
  hardware.facter.reportPath = report;
  dotnix.hardware.graphics.amd.enable = lib.mkIf amdGpu true;
  # an NVIDIA GPU takes a choice (its driver's options): told until made
  warnings = lib.optional (
    lib.elem "10de" gpus && !config.dotnix.hardware.graphics.nvidia.enable
  ) "an NVIDIA GPU: see dotnix.hardware.graphics.nvidia";
}
