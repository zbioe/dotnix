# lib/facter.nix on reports like dotnix-install writes: the nixos-hardware
# modules it picks, the AMD graphics option, the NVIDIA warning
{ lib }:
let
  # module names in place of the modules
  inputs.hardware.nixosModules = lib.genAttrs [
    "common-cpu-amd"
    "common-cpu-amd-pstate"
    "common-cpu-intel"
    "common-gpu-amd"
    "common-gpu-intel"
    "common-pc"
    "common-pc-laptop"
  ] lib.id;
  host =
    report:
    import ../lib/facter.nix { inherit lib; } report {
      inherit inputs;
      config.dotnix.hardware.graphics.nvidia.enable = false;
    };
  expect =
    name: got: want:
    lib.assertMsg (got == want) "${name}: got ${builtins.toJSON got}, want ${builtins.toJSON want}";
  desktop = host ./facter/desktop-amd.json;
  laptop = host ./facter/laptop-intel.json;
  nvidia = host ./facter/desktop-nvidia.json;
in
assert expect "desktop" desktop.imports [
  "common-cpu-amd"
  "common-cpu-amd-pstate"
  "common-gpu-amd"
  "common-pc"
];
assert expect "desktop graphics" desktop.dotnix.hardware.graphics.amd.enable.condition true;
assert expect "desktop warnings" desktop.warnings [ ];
assert expect "laptop graphics" laptop.dotnix.hardware.graphics.amd.enable.condition false;
assert expect "laptop" laptop.imports [
  "common-cpu-intel"
  "common-pc-laptop"
];
assert expect "nvidia" nvidia.imports [
  "common-cpu-amd"
  "common-cpu-amd-pstate"
  "common-pc"
];
assert expect "nvidia warnings" (lib.length nvidia.warnings) 1;
true
