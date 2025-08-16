{ username, ... }:
{
  modules = {
    user = {
      name = username;
      hashedPassword = "$y$j9T$aUrSFZjFUIfKKBQ/C.bXY/$mS1UQvVwaBs6.777A7vnuMl3kGsWXpU0gY2VdtwdWi0";
      uid = 1000;
      authorizedKeys = import ./keys.nix;
      extraGroups = [
        "wheel"
        "users"
        "input"
        "networkmanager"
        "audio"
        "video"
        "disk"
        "nixbld"
        "systemd-journal"
        "bluetooth"
        "dbus"
      ];
    };
  };
}
