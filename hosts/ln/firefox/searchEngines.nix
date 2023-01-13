{ pkgs }: {

  "Nix Packages" = {
    urls = [{
      template = "https://search.nixos.org/packages";
      params = [
        {
          name = "type";
          value = "packages";
        }
        {
          name = "query";
          value = "{searchTerms}";
        }
      ];
    }];
    icon =
      "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
    definedAliases = [ "@np" ];
  };

  "Nix Options" = {
    urls = [{
      template = "https://search.nixos.org/options";
      params = [
        {
          name = "type";
          value = "options";
        }
        {
          name = "query";
          value = "{searchTerms}";
        }
      ];
    }];

    icon =
      "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
    definedAliases = [ "@no" ];
  };

  "Home Manager" = {
    urls = [{
      template =
        "https://mipmip.github.io/home-manager-option-search/?{searchTerms}";
    }];

    icon =
      "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
    definedAliases = [ "@hm" ];
  };

  "NixOS Wiki" = {
    urls =
      [{ template = "https://nixos.wiki/index.php?search={searchTerms}"; }];
    iconUpdateURL = "https://nixos.wiki/favicon.png";
    updateInterval = 24 * 60 * 60 * 1000; # every day
    definedAliases = [ "@nw" ];
  };

  "Rust Doc" = {
    urls = [{
      template = "https://docs.rs/search/latest/search/?search={searchTerms}";
    }];
    iconUpdateURL =
      "https://doc.rust-lang.org/book/img/ferris/does_not_compile.svg";
    updateInterval = 24 * 60 * 60 * 1000; # every day
    definedAliases = [ "@rd" ];
  };

  "Github" = {
    urls = [{
      template = "https://github.com/search";
      params = [{
        name = "q";
        value = "{searchTerms}";
      }];
    }];
    iconUpdateURL = "https://github.com/fluidicon.png";
    updateInterval = 24 * 60 * 60 * 1000; # every day
    definedAliases = [ "@github" "@gh" ];
  };

  "Google".metaData.alias =
    "@g"; # builtin engines only support specifying one additional alias

  "YouTube" = {
    urls = [{
      template = "https://youtube.com/results";
      params = [{
        name = "search_query";
        value = "{searchTerms}";
      }];
    }];
    iconUpdateURL =
      "https://www.youtube.com/s/desktop/0c0c1a38/img/favicon_144x144.png";
    updateInterval = 24 * 60 * 60 * 1000; # every day
    definedAliases = [ "@youtube" "@yt" ];
  };

}
