# The dotnix desktop: bx and te are the same machine, so everything they
# run is here; hosts/<host> only adds its hardware
{ pkgs, ... }:
{
  dotnix = {
    core = {
      boot = {
        enable = true;
        kernel = pkgs.linuxPackages_zen;
      };
      compat.enable = true;
      updates.enable = true;
      # the login password, searx's key and the Wi-Fi networks: secrets/common.yaml
      secrets.enable = true;
    };

    hardware = {
      graphics.enable = true;
      audio = {
        enable = true;
        server = "pipewire";
        noiseSuppression.enable = true;
      };
      bluetooth = {
        enable = true;
        powerOnBoot = true;
      };
      keyboard = {
        enable = true;
        kanata = {
          internal.enable = true;
          external.enable = true;
        };
      };
      ddc.enable = true;
      webcam.enable = true;
    };

    network = {
      ssh.enable = true;
      wifi.enable = true;
      vpn = {
        proton.enable = true;
        warp.enable = true;
      };
    };

    desktop = {
      enable = true;
      mango.enable = true;
      default = "mango";
      greeter = "sddm";
      autoLogin = true;
      inputMethod = "fcitx5";
      secrets = "gnome-keyring";
      fonts.enable = true;
      bootScreens.enable = true;
      browsers = {
        librewolf.enable = true;
        chromium.enable = true;
        brave.enable = true;
        default = "brave";
        protonPass.enable = true;
      };
    };

    services = {
      containers = {
        docker.enable = true;
        distrobox.enable = true;
      };
      vms = {
        libvirt.enable = true;
        waydroid.enable = true;
      };
      ai = {
        ollama.enable = true;
        openWebui.enable = true;
      };
      mail = {
        protonBridge.enable = true;
        mu.enable = true;
      };
      flatpak.enable = true;
      searx.enable = true;
      kdeconnect.enable = true;
      localsend.enable = true;
    };

    packages = {
      base.enable = true;
      desktop.enable = true;
      nix.enable = true;
      dev.enable = true;
      cloud.enable = true;
      ai.enable = true;
      security.enable = true;
      media.enable = true;
      office.enable = true;
      chat.enable = true;
      games.enable = true;
      phone.enable = true;
    };
  };
}
