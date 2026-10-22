{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  cfg = config.dotnix.core.user;
  keys = import ./keys.nix;
in
{
  options.dotnix.core.user = {
    name = lib.mkOption {
      type = lib.types.str;
      default = username;
    };
    hashedPassword = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      # weakPass: the live ISO's, and a new install's until changed
      default = "$y$j9T$FJRz6zSHOa1MWfrJXV6u71$bfclDgI8hZmGxlo7XzzdjgB31FGjxwQikdxudXKTqV8";
    };
    passwordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/persist/secrets/zbioe.passwd";
      description = "Hashed password kept outside the (public) flake; wins over hashedPassword.";
    };
  };

  config = {
    users.users.root.openssh.authorizedKeys.keys = keys;
    users.users.${cfg.name} = {
      isNormalUser = true;
      uid = 1000;
      description = "${cfg.name} account";
      shell = pkgs.fish;
      hashedPassword = if cfg.passwordFile == null then cfg.hashedPassword else null;
      hashedPasswordFile = cfg.passwordFile;
      openssh.authorizedKeys.keys = keys;
      extraGroups = [
        "wheel"
        "users"
        "input"
        "uinput"
        "networkmanager"
        "audio"
        "video"
        "disk"
        "nixbld"
        "systemd-journal"
        "dbus"
        "bluetooth"
        "adbusers"
        "i2c" # monitor brightness over DDC/CI (ddcutil)
        "libvirtd"
        "kvm"
      ];
    };
    programs.fish.enable = true;
  };
}
