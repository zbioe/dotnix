{ pkgs, config, lib, options, ... }:
with lib;
with lib.my;
let cfg = config.modules.boot.efi;
in {
  options.modules.boot.efi = with types; {
    enable = mkBoolOpt true;
    device = mkOpt' str "nodev" "grub device";
    mountPoint = mkOpt' str "/boot" "efi mount point";
  };
  config = mkIf (config.modules.boot.enable && cfg.enable) {
    boot.loader.grub.efiSupport = true;
    boot.loader.grub.device = cfg.device;
    boot.loader.efi.efiSysMountPoint = cfg.mountPoint;
    boot.loader.efi.canTouchEfiVariables = true;
  };
}
