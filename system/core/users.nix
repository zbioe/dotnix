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
    others = lib.mkOption {
      default = { };
      example.amanda.passwordFile = "/persist/secrets/amanda.passwd";
      description = "Accounts of the other people using the machine: no sudo, their own home.";
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            description = lib.mkOption {
              type = lib.types.str;
              default = "";
            };
            passwordFile = lib.mkOption {
              type = lib.types.str;
              description = "Hashed password (mkpasswd), outside the flake.";
            };
            packages = lib.mkOption {
              type = lib.types.listOf lib.types.package;
              default = [ ];
              description = "Programs only this account has.";
            };
          };
        }
      );
    };
  };

  config = {
    # (mkMerge: the names come from an option)
    users.users = lib.mkMerge [
      (lib.mapAttrs (_: other: {
        isNormalUser = true;
        inherit (other) description packages;
        hashedPasswordFile = other.passwordFile;
        extraGroups = [
          "users"
          "networkmanager"
          "audio"
          "video"
        ];
      }) cfg.others)
      {
        root.openssh.authorizedKeys.keys = keys;
        ${cfg.name} = {
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
      }
    ];
    programs.fish.enable = true;
  };
}
