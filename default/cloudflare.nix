{
  unstable,
  ...
}:

{
  services.cloudflare-warp = {
    enable = true;
    package = unstable.cloudflare-warp;
  };
  environment.systemPackages = [ unstable.cloudflared ];
  systemd.user.services.warp-taskbar.wantedBy = [ "graphical.target" ];

  fileSystems."/var/lib/cloudflare-warp" = {
    device = "/var/lib/nodatacow/cloudflare-warp";
    fsType = "none";
    options = [ "bind" ];
  };
}
