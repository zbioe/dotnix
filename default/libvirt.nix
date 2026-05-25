{
  unstable,
  username,
  ...
}:

{
  virtualisation.libvirtd.enable = true;

  programs.virt-manager.enable = true;

  users.users.${username}.extraGroups = [
    "libvirtd"
    "kvm"
  ];

  environment.systemPackages = with unstable; [
    spice
    spice-gtk
    spice-protocol
    virtio-win
    win-spice
  ];
}
