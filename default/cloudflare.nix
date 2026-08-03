{
  unstable,
  ...
}:

{
  services.cloudflare-warp = {
    enable = true;
    package = unstable.cloudflare-warp;
  };
  environment.systemPackages = with unstable; [
    cloudflared
    cloudflare-cli
  ];
  systemd.user.services.warp-taskbar.wantedBy = [ "graphical.target" ];

  fileSystems."/var/lib/cloudflare-warp" = {
    device = "/var/lib/nodatacow/cloudflare-warp";
    fsType = "none";
    options = [ "bind" ];
  };
}
