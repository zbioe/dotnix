{
  config,
  lib,
  pkgs,
  unstable,
  dotlib,
  ...
}:
let
  cfg = config.dotnix.services.vms;
in
{
  options.dotnix.services.vms = {
    enable = lib.mkEnableOption "virtual machines";
    libvirt.enable = dotlib.mkItem cfg "libvirt (virt-manager)";
    waydroid.enable = dotlib.mkItem cfg "Waydroid (Android)";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.libvirt.enable {
      virtualisation.libvirtd = {
        enable = true;
        qemu.swtpm.enable = true;
      };
      virtualisation.spiceUSBRedirection.enable = true;
      # the VMs' disks and libvirt's own key: kept, outside snapshots and backup
      environment.persistence."/var/lib/nodatacow".directories =
        lib.mkIf config.dotnix.storage.impermanence.enable
          [ "/var/lib/libvirt" ];
      programs.virt-manager.enable = true;
      users.users.${config.dotnix.core.user.name}.extraGroups = [
        "libvirtd"
        "kvm"
      ];
      environment.systemPackages = with unstable; [
        swtpm # TPM emulator for Windows guests
        spice # remote display protocol
        spice-gtk # spice client widgets
        spice-protocol # spice headers
        virtio-win # Windows guest drivers
        win-spice # Windows guest tools
      ];
    })
    (lib.mkIf cfg.waydroid.enable {
      virtualisation.waydroid = {
        enable = true;
        package = pkgs.waydroid-nftables;
      };
      fileSystems."/var/lib/waydroid" = {
        device = "/var/lib/nodatacow/waydroid";
        fsType = "none";
        options = [ "bind" ];
      };
      environment.systemPackages = with pkgs; [
        waydroid-helper # waydroid settings GUI
        mtkclient # MediaTek flash and repair tool
      ];
      networking.firewall.trustedInterfaces = [ "waydroid0" ];
      boot.kernel.sysctl = {
        "net.ipv4.ip_forward" = 1;
        "net.ipv4.conf.all.forwarding" = 1;
      };
    })
  ];
}
