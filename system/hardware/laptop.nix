# A laptop: TLP tunes it on AC and on battery, and its power profiles
# (performance, balanced, power saver) are the ones the bar's control center
# switches (tlp-pd: the power-profiles-daemon interface). The battery itself,
# its warnings and its charge limit come from UPower (hardware/default.nix)
{ config, lib, ... }:
let
  cfg = config.dotnix.hardware.laptop;
in
{
  options.dotnix.hardware.laptop.enable =
    lib.mkEnableOption "laptop power management (TLP, power profiles)";

  config = lib.mkIf cfg.enable {
    services.tlp = {
      enable = true;
      pd.enable = true;
      settings = {
        # full speed on AC, saving on battery
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
        CPU_BOOST_ON_AC = 1;
        CPU_BOOST_ON_BAT = 0;
        PLATFORM_PROFILE_ON_AC = "performance";
        PLATFORM_PROFILE_ON_BAT = "low-power";
      };
    };
    # (nixos-hardware's laptop profiles may turn it on; tlp-pd takes its place)
    services.power-profiles-daemon.enable = false;
  };
}
