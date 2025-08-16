# From: kloenk/nixfiles/modules/evremap/default.nix
{
  config,
  pkgs,
  lib,
  utils,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    ;

  cfg = config.modules.evremap;
  tomlFormat = pkgs.formats.toml { };
  configFile = config: tomlFormat.generate "remap.toml" config;

  deviceOpts =
    { name, ... }:
    {
      freeformType = tomlFormat.type;
      options = {
        device_name = mkOption {
          type = types.str;
          default = name;
        };
      };
    };
in
{
  options.modules.evremap = {
    enable = mkEnableOption "evremap";

    package = mkOption {
      type = types.package;
      default = pkgs.evremap;
    };

    devices = mkOption { type = types.attrsOf (types.submodule deviceOpts); };
  };

  config = mkIf cfg.enable {
    systemd.services = lib.mapAttrs' (
      name: config:
      lib.nameValuePair "evremap-${utils.escapeSystemdPath name}" {
        wantedBy = [ "basic.target" ];
        unitConfig = {
          Restart = "on-failure";
        };
        serviceConfig = {
          ExecStart = "${cfg.package}/bin/evremap remap ${configFile config}";
          User = "root";
          Group = "input";
          DynamicUser = false;
          PrivateTmp = true;
        };
      }
    ) cfg.devices;
  };
}
