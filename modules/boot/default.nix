{pkgs, config, lib, options, ...}:
with lib;
with lib.my;
let 
  cfg = config.modules.boot;
in {
  imports = [
    ./efi.nix
  ];
  options.modules.boot = with types; {
    enable = mkBoolOpt false;
    timeout = mkOpt' int 1 "GRUB timeout";
  };
  config = mkIf cfg.enable {
    boot.loader.grub.enable = true;
    boot.loader.timeout = cfg.timeout;
  };
}
