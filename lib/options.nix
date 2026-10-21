# The three kinds of dotnix options: items of a group, the main one among
# them, and package groups.
{ lib }:
let
  inherit (lib) mkOption types;
in
{
  # an item of a group: on with the group unless set
  mkItem =
    group: description:
    mkOption {
      type = types.bool;
      default = group.enable;
      defaultText = lib.literalMD "the group's `enable`";
      description = "Whether to enable ${description}.";
    };

  # the main item of a group (opens links, logs in by default...)
  mkMain =
    items: description:
    mkOption {
      type = types.nullOr (types.enum items);
      default = null;
      description = "The ${description}; it must be enabled.";
    };

  assertMain = name: cfg: {
    assertion = cfg.default == null || cfg.${cfg.default}.enable;
    message = "${name}.default is ${toString cfg.default}, which is not enabled";
  };

  mkPackages = description: {
    enable = lib.mkEnableOption description;
    exclude = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "julia" ];
      description = "Package names left out of the group.";
    };
    extra = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Packages added to the group.";
    };
  };

  packagesOf = cfg: pkgs: lib.filter (p: !lib.elem (lib.getName p) cfg.exclude) pkgs ++ cfg.extra;
}
