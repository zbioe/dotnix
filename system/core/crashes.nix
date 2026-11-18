# A frozen machine reboots itself and leaves its last kernel messages
# behind: the watchdogs turn a hard or soft lockup into a panic, the panic
# writes the log to the firmware (EFI pstore), and systemd-pstore copies it
# to /var/lib/systemd/pstore on the next boot (journalctl -b -1 shows it)
{ config, lib, ... }:
{
  options.dotnix.core.crashes.enable =
    lib.mkEnableOption "lockups rebooting the machine with their log kept";

  config = lib.mkIf config.dotnix.core.crashes.enable {
    boot.kernelParams = [
      "nmi_watchdog=1"
      "hardlockup_panic=1"
      "softlockup_panic=1"
      # back up 10 s after the panic, instead of waiting for the power button
      "panic=10"
    ];
    # TLP turns the lockup watchdog off to save power
    services.tlp.settings.NMI_WATCHDOG = lib.mkIf config.services.tlp.enable 1;
    environment.persistence."/persist".directories =
      lib.mkIf config.dotnix.storage.impermanence.enable
        [
          "/var/lib/systemd/pstore"
        ];
  };
}
