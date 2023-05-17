{ ... }: {
  imports = [ ./hardware.nix ./config.nix ];

  user.name = "zbioe";
  time.zone = "America/Sao_Paulo";
  host = {
    name = "ln";
    i18n = "en_US.UTF-8";
  };

  modules = {
    system.stateVersion = "22.05";

    bluetooth = {
      enable = true;
      powerOnBoot = false;
    };

    keyboard = {
      layout = "br";
      variant = "abnt2";
      model = "thinkpad";
      options = [ "ctrl:swapcaps" ];
    };

    network = {
      enable = true;
      dns = [ "1.1.1.1" "1.0.0.1" ];
    };

    protonvpn = let
      country = "BR";
      vpnMap = {
        BR = {
          IP = "149.102.251.97";
          PubKey = "0FnhfTGup0LHPmBCsuDN4tVqlgOaItDwayQokhWapFQ=";
        };
        US = {
          IP = "31.13.189.242";
          PubKey = "iJIw5umGxtrrSIRxVrSF1Ofu5IDphpBpAJOvsrG4FiI=";
        };
        JP = {
          IP = "37.19.205.155";
          PubKey = "d38wbEHG3sJG+0s34lCGtYU2AwZ9E/WrP3qM9gL7Xi8=";
        };
        AR = {
          IP = "66.90.72.170";
          PubKey = "BSXSJgI+cpLA2TrGL2swcqaXuCSjNNw9PVK7E0yCqFo=";
        };
        CH = {
          IP = "146.70.113.98";
          PubKey = "/AEriTfHYyrhW+bj1cDy9RroL4j4o1tv9sw4m+aB8lA=";
        };
        RU = {
          IP = "5.8.16.162";
          PubKey = "pgiEIxgoVmEZq0geYfpa4o3aDWEuTUvmwR/rhsivnUc=";
        };
      };
    in {
      enable = true;
      autostart = true;
      endpoint = {
        ip = vpnMap.${country}.IP;
        publicKey = vpnMap.${country}.PubKey;
      };
      interface = {
        name = "protonvpn";
        privateKeyFile = "/root/protonvpn/${country}.key";
      };
    };

    audio.enable = true;

    wm = {
      enable = true;
      leftwm.enable = true;
      herbstluft.enable = true;
      gdm.enable = true;
    };
  };

}
