# LibreWolf: its own hardening, locked, plus Privacy Guides' and arkenfox's
# recommendations; only the extensions listed here install. It follows `theme`
# live through the nix-theme bridge and a patched Dark Reader, from the store.
# uBlock's rules and the cookie exceptions are private: home/desktop/librewolf.
{
  config,
  lib,
  pkgs,
  unstable,
  base16,
  ...
}:
let
  cfg = config.dotnix.desktop.browsers;
  darkreader = pkgs.callPackage ../../../pkgs/darkreader { };
  nixTheme = pkgs.callPackage ../../../pkgs/nix-theme {
    themeSet = import ../../../home/theme/themes.nix { inherit pkgs; };
    inherit (base16.lib { inherit pkgs lib; }) mkSchemeAttrs;
  };

  amo = slug: {
    installation_mode = "force_installed";
    install_url = "https://addons.mozilla.org/firefox/downloads/latest/${slug}/latest.xpi";
  };

  extensions = {
    "uBlock0@raymondhill.net" = amo "ublock-origin";
    "@testpilot-containers" = amo "multi-account-containers";
    "{d7742d87-e61d-4b78-b8a1-b469842139fa}" = amo "vimium-ff";
    "sponsorBlocker@ajay.app" = amo "sponsorblock";
    "{c2e013df-64f1-4c22-8683-64b230f6e393}" = amo "ctrl_tabs";
    ${darkreader.addonId} = {
      installation_mode = "force_installed";
      install_url = "file://${darkreader}/darkreader.xpi";
      # keep AMO from replacing it with the unpatched release
      updates_disabled = true;
    };
    ${nixTheme.addonId} = {
      installation_mode = "force_installed";
      install_url = "file://${nixTheme}/nix-theme.xpi";
    };
  }
  // lib.optionalAttrs cfg.protonPass.enable {
    "78272b6fa58f4a1abaac99321d503a20@proton.me" = amo "proton-pass";
  }
  // lib.optionalAttrs config.dotnix.desktop.activity.enable {
    "{ef87d84c-2127-493f-b952-5b4e744245bc}" = amo "aw-watcher-web";
  }
  // {
    # anything else: unsigned add-ons are allowed (for the two above)
    "*".installation_mode = "blocked";
  };

  # locked: changing them takes this file
  locked = {
    # Privacy Guides: Enhanced Tracking Protection strict, HTTPS everywhere,
    # no search suggestions or Firefox Suggest, no telemetry
    "browser.contentblocking.category" = "strict";
    "dom.security.https_only_mode" = true;
    "browser.search.suggest.enabled" = false;
    "browser.urlbar.suggest.searches" = false;
    "browser.urlbar.quicksuggest.enabled" = false;
    "browser.urlbar.suggest.quicksuggest.sponsored" = false;
    "browser.urlbar.suggest.quicksuggest.nonsponsored" = false;
    "datareporting.healthreport.uploadEnabled" = false;
    "app.shield.optoutstudies.enabled" = false;
    "browser.crashReports.unsubmittedCheck.autoSubmit2" = false;
    # cookies and site data gone on close, but for the exceptions
    "privacy.sanitize.sanitizeOnShutdown" = true;
    "privacy.clearOnShutdown_v2.cookiesAndStorage" = true;
    "privacy.clearOnShutdown_v2.cache" = true;
    # arkenfox: fingerprinting resistance, nothing fetched before a click,
    # WebRTC without the local addresses
    "privacy.resistFingerprinting" = true;
    "network.prefetch-next" = false;
    "network.dns.disablePrefetch" = true;
    "network.predictor.enabled" = false;
    "network.http.speculative-parallel-limit" = 0;
    "browser.urlbar.speculativeConnect.enabled" = false;
    "browser.places.speculativeConnect.enabled" = false;
    "media.peerconnection.ice.default_address_only" = true;
    "privacy.globalprivacycontrol.enabled" = true;
    # containers (Multi-Account Containers)
    "privacy.userContext.enabled" = true;
    "privacy.userContext.ui.enabled" = true;
    # the system resolver does DNS over TLS
    "network.trr.mode" = 5;
    # passwords live in Proton Pass
    "signon.rememberSignons" = false;
    # the two add-ons built here are unsigned
    "xpinstall.signatures.required" = false;
  };

  # defaults: the UI can still change them
  defaults = {
    "sidebar.verticalTabs" = true;
    "sidebar.visibility" = "hide-sidebar";
    "sidebar.main.tools" = "history,bookmarks";
    "browser.toolbars.bookmarks.visibility" = "never";
  };

  prefs =
    kind: set:
    lib.concatStrings (
      lib.mapAttrsToList (k: v: "${kind}(${builtins.toJSON k}, ${builtins.toJSON v});\n") set
    );

  librewolf = unstable.librewolf.override {
    nativeMessagingHosts = [ nixTheme ];
    extraPrefs = prefs "lockPref" locked + prefs "defaultPref" defaults;
    extraPolicies = {
      ExtensionSettings = extensions;
      HttpsOnlyMode = "force_enabled";
      DisableFirefoxAccounts = true;
      FirefoxSuggest = {
        WebSuggestions = false;
        SponsoredSuggestions = false;
        ImproveSuggest = false;
        Locked = true;
      };
    };
  };
in
lib.mkIf cfg.librewolf.enable {
  environment.systemPackages = [ librewolf ];
}
