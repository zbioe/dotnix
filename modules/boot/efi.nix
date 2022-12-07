{pkgs, config, lib, options, ...}:
with lib;
with lib.my;
let 
  cfg = config.modules.boot.efi;
in {
  options.modules.boot.efi = with types; {
    enable = mkBoolOpt true;
    device = mkOpt' str "nodev" "grub device";
  };
  config = mkIf (config.modules.boot.enable && cfg.enable) {
    boot.loader.grub.efiSupport = true;
    boot.loader.grub.device = "nodev";
    boot.loader.efi.efiSysMountPoint = "/boot/efi";
    boot.loader.efi.canTouchEfiVariables = true;
  };
}
