{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) types mkOption;
  cfg = config.modules;
in
{
  imports = [
    ./audio.nix
    ./nvidia.nix
    ./boot.nix
    ./stylix.nix
    ./evremap.nix
    ./bluetooth.nix
    ./protonvpn.nix
  ];
  options.modules = with types; {
    user.name = mkOption {
      type = str;
      default = "default";
      description = ''
        username used to create the user
      '';
    };
    user.uid = mkOption {
      type = (nullOr int);
      default = 1000;
      description = ''
        uid for the ${cfg.user.name} user
      '';
    };
    user.shell = mkOption {
      type = package;
      default = pkgs.bash;
      description = ''
        shell used by the ${cfg.user.name} user
      '';
    };
    user.description = mkOption {
      type = str;
      default = "${cfg.user.name} account";
      description = ''
        description of the ${cfg.user.name} user
      '';
    };
    user.extraGroups = mkOption {
      type = (listOf str);
      default = [ "wheel" ];
      description = ''
        extra groups for the ${cfg.user.name} user
      '';
    };
    user.hashedPassword = mkOption {
      type = str;
      # weakPass
      default = "$y$j9T$FJRz6zSHOa1MWfrJXV6u71$bfclDgI8hZmGxlo7XzzdjgB31FGjxwQikdxudXKTqV8";
      description = ''
        hashed password for the ${cfg.user.name} user
        default: "weakPass"
      '';
    };
    user.wheelNeedsPassword = mkOption {
      type = bool;
      default = false;
      description = ''
        sudo whitout password
      '';
    };
    user.authorizedKeys = mkOption {
      type = (listOf str);
      default = [ ];
      description = ''
        authorized keys for the default user
      '';
    };
    experimental-features = mkOption {
      type = (listOf str);
      default = [
        "nix-command"
        "flakes"
        "pipe-operators"
      ];
      description = "experimental features";
    };
    host.name = mkOption {
      type = str;
      default = "nixos";
      description = "hostname";
    };
    host.i18n = mkOption {
      type = str;
      default = "pt_BR.UTF-8";
      description = "default locale";
    };
    time.zone = mkOption {
      type = str;
      default = "America/Sao_Paulo";
      description = "time zone configuration";
    };
  };
  config = {
    users.users = {
      root = {
        openssh = {
          authorizedKeys = {
            keys = cfg.user.authorizedKeys;
          };
        };
      };
      "${cfg.user.name}" = {
        isNormalUser = true;
        uid = cfg.user.uid;
        description = cfg.user.description;
        hashedPassword = cfg.user.hashedPassword;
        extraGroups = cfg.user.extraGroups;
        shell = cfg.user.shell;
        openssh = {
          authorizedKeys = {
            keys = cfg.user.authorizedKeys;
          };
        };
      };
    };
    networking.hostName = cfg.host.name;
    i18n.defaultLocale = cfg.host.i18n;
    security.sudo.wheelNeedsPassword = cfg.user.wheelNeedsPassword;
    time.timeZone = cfg.time.zone;
    nix.settings =
      let
        users = [
          "root"
          "${cfg.user.name}"
        ];
      in
      {
        trusted-users = users;
        allowed-users = users;
        experimental-features = cfg.experimental-features;
	substituters = [
	  "https://cache.nixos.org/"
	  "https://cachix.cachix.org"
	  "https://cache.flox.dev"
	  "https://hyprland.cachix.org"
	  "https://nix-community.cachix.org"
	];

	trusted-public-keys = [
	  "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
	  "cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM="
	  "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
	  "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
	  "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
	];
      };
  };

}
