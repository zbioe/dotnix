{
  unstable,
  username,
  ...
}:

{
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      swtpm.enable = true;
    };
  };

  virtualisation.spiceUSBRedirection.enable = true;
  programs.virt-manager.enable = true;

  users.users.${username}.extraGroups = [
    "libvirtd"
    "kvm"
  ];

  environment.systemPackages = with unstable; [
    swtpm
    spice
    spice-gtk
    spice-protocol
    virtio-win
    win-spice
  ];
}
