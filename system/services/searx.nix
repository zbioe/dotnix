# a private search engine on localhost:8822
{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.dotnix.services.searx.enable = lib.mkEnableOption "searx";

  config = lib.mkIf config.dotnix.services.searx.enable {
    services.searx = {
      enable = true;
      package = pkgs.searxng;
      # SEARX_SECRET_KEY=..., root only, outside the (public) repo
      environmentFile = "/persist/secrets/searx.env";
      settings = {
        server = {
          port = 8822;
          bind_address = "127.0.0.1";
          secret_key = "$SEARX_SECRET_KEY";
        };

        search = {
          safe_search = 0;
          autocomplete = "duckduckgo";
          default_lang = "pt-BR";
        };

        ui = {
          theme = "simple";
          default_locale = "pt-BR";
        };

        engines = lib.mkForce [
          {
            name = "startpage";
            engine = "startpage";
            shortcut = "s";
            weight = 3;
          }
          {
            name = "duckduckgo";
            engine = "duckduckgo";
            shortcut = "d";
            weight = 2;
          }
          {
            name = "brave";
            engine = "brave";
            shortcut = "b";
            weight = 1;
          }
          {
            name = "bing";
            engine = "bing";
            shortcut = "bi";
            weight = 1;
          }

          # built-in, stable dev engines
          {
            name = "github";
            engine = "github";
            shortcut = "gh";
          }
          {
            name = "stackoverflow";
            engine = "stackexchange";
            shortcut = "st";
          }
          {
            name = "nixos wiki";
            engine = "mediawiki";
            base_url = "https://wiki.nixos.org/";
            shortcut = "nw";
          }
        ];
      };
    };
    # its secret key is made on the first boot of each host (a fresh install,
    # the live ISO), random and never in the flake
    systemd.services.searx-secret = {
      description = "Create the searx secret key";
      wantedBy = [ "searx-init.service" ];
      before = [ "searx-init.service" ];
      unitConfig.ConditionPathExists = "!/persist/secrets/searx.env";
      serviceConfig.Type = "oneshot";
      path = [
        pkgs.coreutils
        pkgs.openssl
      ];
      script = ''
        install -d -m 700 /persist/secrets
        umask 077
        printf 'SEARX_SECRET_KEY=%s\n' "$(openssl rand -hex 32)" > /persist/secrets/searx.env
      '';
    };
  };
}
