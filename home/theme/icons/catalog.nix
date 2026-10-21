# Icon packs of the bar, switched live by `theme icons` (icons.sh): one font
# per pack, each tag and each of the bar's glyphs an icon by its name in it
{ pkgs, noctalia }:
let
  inherit (pkgs) lib;
  # noctalia's own icons, also as a font the tags' labels can name
  tabler = pkgs.runCommand "noctalia-tabler-font" { } ''
    install -Dm444 ${noctalia}/share/noctalia/assets/fonts/noctalia-tabler.ttf $out/share/fonts/truetype/noctalia-tabler.ttf
  '';
  # the same tag icons in the three Material Symbols styles
  material = {
    "1" = "playing_cards";
    "2" = "web";
    "3" = "mode_fan";
    "4" = "counter_4";
    "5" = "chat";
    "6" = "casino";
    "7" = "calendar_view_week";
    "8" = "all_inclusive";
    "9" = "terminal";
    "10" = "code";
  };
  materialPack = style: {
    title = "Material ${style}";
    family = "Material Symbols ${style}";
    package = pkgs.material-symbols;
    file = "MaterialSymbols${style}[FILL,GRAD,opsz,wght].ttf";
    weight = 400;
    tags = material;
    bar = {
      "caffeine-on" = "coffee";
      "caffeine-off" = "bedtime";
      "bluetooth" = "bluetooth";
      "bluetooth-connected" = "bluetooth_connected";
      "bluetooth-off" = "bluetooth_disabled";
      "memory" = "memory";
      "cpu-usage" = "speed";
      "storage" = "hard_drive";
      "volume-high" = "volume_up";
      "volume-low" = "volume_down";
      "volume-mute" = "volume_off";
      "wifi" = "signal_wifi_4_bar";
      "wifi-3" = "network_wifi_3_bar";
      "wifi-2" = "network_wifi_2_bar";
      "wifi-1" = "network_wifi_1_bar";
      "wifi-0" = "signal_wifi_0_bar";
      "wifi-off" = "signal_wifi_off";
      "wifi-question" = "signal_wifi_statusbar_not_connected";
      "wifi-exclamation" = "signal_wifi_bad";
      "ethernet" = "settings_ethernet";
      "ethernet-off" = "signal_disconnected";
      "shield-check" = "verified_user";
      "shield-off" = "remove_moderator";
      "palette" = "palette";
      "keyboard" = "keyboard";
      "clipboard" = "content_paste";
      "bell" = "notifications";
      "bell-off" = "notifications_off";
      "battery-4" = "battery_full";
      "battery-3" = "battery_5_bar";
      "battery-2" = "battery_3_bar";
      "battery-1" = "battery_1_bar";
      "battery-0" = "battery_0_bar";
      "battery-charging" = "battery_charging_full";
      "battery-plugged" = "power";
      "battery-exclamation" = "battery_alert";
    };
  };
in
rec {
  default = "nerd";

  # the glyphs the bar's widgets draw, by noctalia's names (a widget picks one
  # by its state), in the order the panel lists them
  bar = [
    {
      name = "caffeine-on";
      title = "Caffeine on";
    }
    {
      name = "caffeine-off";
      title = "Caffeine off";
    }
    {
      name = "bluetooth";
      title = "Bluetooth";
    }
    {
      name = "bluetooth-connected";
      title = "Bluetooth connected";
    }
    {
      name = "bluetooth-off";
      title = "Bluetooth off";
    }
    {
      name = "memory";
      title = "RAM";
    }
    {
      name = "cpu-usage";
      title = "CPU";
    }
    {
      name = "storage";
      title = "Disk";
    }
    {
      name = "volume-high";
      title = "Volume high";
    }
    {
      name = "volume-low";
      title = "Volume low";
    }
    {
      name = "volume-mute";
      title = "Volume muted";
    }
    {
      name = "wifi";
      title = "Wi-Fi full";
    }
    {
      name = "wifi-3";
      title = "Wi-Fi 3/4";
    }
    {
      name = "wifi-2";
      title = "Wi-Fi 2/4";
    }
    {
      name = "wifi-1";
      title = "Wi-Fi 1/4";
    }
    {
      name = "wifi-0";
      title = "Wi-Fi weak";
    }
    {
      name = "wifi-off";
      title = "Wi-Fi off";
    }
    {
      name = "wifi-question";
      title = "Wi-Fi unknown";
    }
    {
      name = "wifi-exclamation";
      title = "Wi-Fi disconnected";
    }
    {
      name = "ethernet";
      title = "Ethernet";
    }
    {
      name = "ethernet-off";
      title = "Ethernet unplugged";
    }
    {
      name = "shield-check";
      title = "VPN";
    }
    {
      name = "shield-off";
      title = "VPN off";
    }
    {
      name = "palette";
      title = "Themes";
    }
    {
      name = "keyboard";
      title = "Shortcuts";
    }
    {
      name = "clipboard";
      title = "Clipboard";
    }
    {
      name = "bell";
      title = "Notifications";
    }
    {
      name = "bell-off";
      title = "Do not disturb";
    }
    {
      name = "battery-4";
      title = "Battery full";
    }
    {
      name = "battery-3";
      title = "Battery 3/4";
    }
    {
      name = "battery-2";
      title = "Battery half";
    }
    {
      name = "battery-1";
      title = "Battery low";
    }
    {
      name = "battery-0";
      title = "Battery empty";
    }
    {
      name = "battery-charging";
      title = "Charging";
    }
    {
      name = "battery-plugged";
      title = "Plugged in";
    }
    {
      name = "battery-exclamation";
      title = "Battery unknown";
    }
    {
      name = "noctalia";
      title = "Control center";
    }
  ];

  # a glyph a pack leaves out keeps Tabler's
  packs = {
    tabler = {
      title = "Tabler";
      family = "noctalia-tabler-icons";
      package = tabler;
      file = "noctalia-tabler.ttf";
      # the font's glyph names are not Tabler's: these are
      names = "${noctalia}/share/noctalia/assets/fonts/tabler.json";
      weight = 400;
      tags = {
        "1" = "clubs";
        "2" = "browser";
        "3" = "propeller";
        "4" = "tallymark-4";
        "5" = "message";
        "6" = "dice-6";
        "7" = "calendar-week";
        "8" = "infinity";
        "9" = "terminal";
        "10" = "code";
      };
      # noctalia draws these already
      bar = { };
    };
    nerd = {
      title = "Nerd Font";
      family = "Symbols Nerd Font";
      package = pkgs.nerd-fonts.symbols-only;
      file = "SymbolsNerdFont-Regular.ttf";
      weight = 400;
      tags = {
        "1" = "md-cards_playing_club";
        "2" = "oct-browser";
        "3" = "md-fan_speed_3";
        "4" = "md-tally_mark_4";
        "5" = "fa-comment";
        "6" = "md-dice_6";
        "7" = "md-calendar_week";
        "8" = "md-roman_numeral_8";
        "9" = "fa-terminal";
        "10" = "cod-code";
      };
      bar = {
        "caffeine-on" = "md-coffee";
        "caffeine-off" = "md-coffee_outline";
        "bluetooth" = "md-bluetooth";
        "bluetooth-connected" = "md-bluetooth_connect";
        "bluetooth-off" = "md-bluetooth_off";
        "memory" = "md-memory";
        "cpu-usage" = "md-speedometer";
        "storage" = "md-harddisk";
        "volume-high" = "md-volume_high";
        "volume-low" = "md-volume_medium";
        "volume-mute" = "md-volume_off";
        "wifi" = "md-wifi_strength_4";
        "wifi-3" = "md-wifi_strength_3";
        "wifi-2" = "md-wifi_strength_2";
        "wifi-1" = "md-wifi_strength_1";
        "wifi-0" = "md-wifi_strength_outline";
        "wifi-off" = "md-wifi_strength_off_outline";
        "wifi-question" = "md-wifi_strength_alert_outline";
        "wifi-exclamation" = "md-wifi_strength_alert_outline";
        "ethernet" = "md-ethernet";
        "ethernet-off" = "md-ethernet_cable_off";
        "shield-check" = "md-shield_check";
        "shield-off" = "md-shield_off_outline";
        "palette" = "md-palette";
        "keyboard" = "md-keyboard";
        "clipboard" = "md-clipboard_outline";
        "bell" = "md-bell_outline";
        "bell-off" = "md-bell_off_outline";
        "battery-4" = "md-battery";
        "battery-3" = "md-battery_70";
        "battery-2" = "md-battery_40";
        "battery-1" = "md-battery_20";
        "battery-0" = "md-battery_outline";
        "battery-charging" = "md-battery_charging";
        "battery-plugged" = "md-power_plug";
        "battery-exclamation" = "md-battery_alert";
      };
    };
    material-outlined = materialPack "Outlined";
    material-rounded = materialPack "Rounded";
    material-sharp = materialPack "Sharp";
    lucide = {
      title = "Lucide";
      family = "lucide";
      package = pkgs.lucide;
      file = "Lucide.ttf";
      weight = 400;
      tags = {
        "1" = "club";
        "2" = "app-window";
        "3" = "fan";
        "4" = "tally-4";
        "5" = "message-circle";
        "6" = "dice-6";
        "7" = "calendar-range";
        "8" = "infinity";
        "9" = "terminal";
        "10" = "code";
      };
      bar = {
        "caffeine-on" = "coffee";
        "caffeine-off" = "moon";
        "bluetooth" = "bluetooth";
        "bluetooth-connected" = "bluetooth-connected";
        "bluetooth-off" = "bluetooth-off";
        "memory" = "memory-stick";
        "cpu-usage" = "gauge";
        "storage" = "hard-drive";
        "volume-high" = "volume-2";
        "volume-low" = "volume-1";
        "volume-mute" = "volume-x";
        "wifi" = "wifi";
        "wifi-3" = "wifi-high";
        "wifi-2" = "wifi-low";
        "wifi-1" = "wifi-low";
        "wifi-0" = "wifi-zero";
        "wifi-off" = "wifi-off";
        "wifi-question" = "wifi-sync";
        "wifi-exclamation" = "wifi-off";
        "ethernet" = "ethernet-port";
        "ethernet-off" = "unplug";
        "shield-check" = "shield-check";
        "shield-off" = "shield-off";
        "palette" = "palette";
        "keyboard" = "keyboard";
        "clipboard" = "clipboard";
        "bell" = "bell";
        "bell-off" = "bell-off";
        "battery-4" = "battery-full";
        "battery-3" = "battery-medium";
        "battery-2" = "battery-medium";
        "battery-1" = "battery-low";
        "battery-0" = "battery";
        "battery-charging" = "battery-charging";
        "battery-plugged" = "plug-zap";
        "battery-exclamation" = "battery-warning";
      };
    };
    fontawesome = {
      title = "Font Awesome";
      family = "Font Awesome 7 Free";
      package = pkgs.font-awesome;
      file = "Font Awesome 7 Free-Solid-900.otf";
      # the solid style: the free regular one has few icons
      weight = 900;
      tags = {
        "1" = "clover";
        "2" = "window-maximize";
        "3" = "fan";
        "4" = "dice-four";
        "5" = "comment";
        "6" = "dice-six";
        "7" = "calendar-week";
        "8" = "infinity";
        "9" = "terminal";
        "10" = "code";
      };
      # the free solid style has no Bluetooth (a brand) nor Wi-Fi levels
      bar = {
        "caffeine-on" = "mug-hot";
        "caffeine-off" = "mug-saucer";
        "memory" = "memory";
        "cpu-usage" = "gauge-high";
        "storage" = "hard-drive";
        "volume-high" = "volume-high";
        "volume-low" = "volume-low";
        "volume-mute" = "volume-xmark";
        "wifi" = "wifi";
        "ethernet" = "ethernet";
        "ethernet-off" = "plug-circle-xmark";
        "shield-check" = "shield-halved";
        "palette" = "palette";
        "keyboard" = "keyboard";
        "clipboard" = "clipboard";
        "bell" = "bell";
        "bell-off" = "bell-slash";
        "battery-4" = "battery-full";
        "battery-3" = "battery-three-quarters";
        "battery-2" = "battery-half";
        "battery-1" = "battery-quarter";
        "battery-0" = "battery-empty";
        "battery-charging" = "bolt";
        "battery-plugged" = "plug";
        "battery-exclamation" = "triangle-exclamation";
      };
    };
  };

  packages = lib.unique (lib.mapAttrsToList (_: p: p.package) packs);

  # app icon themes (launcher, tray, GTK and Qt apps), a folder each for
  # dark and light; switched live by `theme icons apps`
  appsDefault = "papirus";
  apps = {
    papirus = {
      title = "Papirus";
      package = pkgs.papirus-icon-theme;
      dark = "Papirus-Dark";
      light = "Papirus-Light";
    };
    morewaita = {
      title = "MoreWaita";
      package = pkgs.morewaita-icon-theme;
      dark = "MoreWaita";
      light = "MoreWaita";
    };
    breeze = {
      title = "Breeze";
      package = pkgs.kdePackages.breeze-icons;
      dark = "breeze-dark";
      light = "breeze";
    };
    numix-circle = {
      title = "Numix Circle";
      package = pkgs.numix-icon-theme-circle;
      dark = "Numix-Circle";
      light = "Numix-Circle-Light";
    };
    numix-square = {
      title = "Numix Square";
      package = pkgs.numix-icon-theme-square;
      dark = "Numix-Square";
      light = "Numix-Square-Light";
    };
    tela = {
      title = "Tela";
      package = pkgs.tela-icon-theme;
      dark = "Tela-dark";
      light = "Tela-light";
    };
    qogir = {
      title = "Qogir";
      package = pkgs.qogir-icon-theme;
      dark = "Qogir-Dark";
      light = "Qogir-Light";
    };
    fluent = {
      title = "Fluent";
      package = pkgs.fluent-icon-theme;
      dark = "Fluent-dark";
      light = "Fluent-light";
    };
    whitesur = {
      title = "WhiteSur";
      package = pkgs.whitesur-icon-theme;
      dark = "WhiteSur-dark";
      light = "WhiteSur-light";
    };
    colloid = {
      title = "Colloid";
      package = pkgs.colloid-icon-theme;
      dark = "Colloid-Dark";
      light = "Colloid-Light";
    };
    kora = {
      title = "Kora";
      package = pkgs.kora-icon-theme;
      dark = "kora";
      light = "kora-light";
    };
    reversal = {
      title = "Reversal";
      package = pkgs.reversal-icon-theme;
      dark = "Reversal-dark";
      light = "Reversal";
    };
    flat-remix = {
      title = "Flat Remix";
      package = pkgs.flat-remix-icon-theme;
      dark = "Flat-Remix-Blue-Dark";
      light = "Flat-Remix-Blue-Light";
    };
    yaru = {
      title = "Yaru";
      package = pkgs.yaru-theme;
      dark = "Yaru-dark";
      light = "Yaru";
    };
    beautyline = {
      title = "BeautyLine";
      package = pkgs.beauty-line-icon-theme;
      dark = "BeautyLine";
      light = "BeautyLine";
    };
    candy = {
      title = "Candy";
      package = pkgs.candy-icons;
      dark = "candy-icons";
      light = "candy-icons";
    };
  };

  # every app theme's folders and the ones they inherit, in share/icons (one
  # package: themes ship folders of the same name, breeze and Adwaita among
  # them); the build fails on a folder not found (an inherited one may lack)
  appThemes =
    pkgs.runCommand "app-icon-themes"
      {
        nativeBuildInputs = [ pkgs.python3 ];
        apps = builtins.toJSON (
          lib.mapAttrs (_: a: {
            inherit (a) dark light;
            path = "${a.package}";
          }) apps
        );
        passAsFile = [ "apps" ];
      }
      ''
        python3 - <<'EOF'
        import configparser, json, os, sys
        apps = json.load(open(os.environ["appsPath"]))
        roots = [os.path.join(a["path"], "share/icons") for a in apps.values()]
        out = os.path.join(os.environ["out"], "share/icons")
        os.makedirs(out)
        bad = []
        def link(theme, own, inherited=False):
            if theme == "hicolor" or os.path.exists(os.path.join(out, theme)):
                return
            src = next((os.path.join(r, theme) for r in [own] + roots if os.path.isfile(os.path.join(r, theme, "index.theme"))), None)
            if not src:
                if not inherited:
                    bad.append(f"no icon theme '{theme}'")
                return
            os.symlink(src, os.path.join(out, theme))
            ini = configparser.ConfigParser(interpolation=None, strict=False)
            ini.read(os.path.join(src, "index.theme"))
            for parent in ini.get("Icon Theme", "Inherits", fallback="").split(","):
                if parent.strip():
                    link(parent.strip(), own, True)
        for a in apps.values():
            for theme in (a["dark"], a["light"]):
                link(theme, os.path.join(a["path"], "share/icons"))
        if bad:
            sys.exit("\n".join(sorted(set(bad))))
        EOF
      '';

  # a few icons of every app theme (its dark folder), for the panel
  appPreviews =
    pkgs.runCommand "app-icon-previews"
      {
        nativeBuildInputs = [ pkgs.python3 ];
        apps = builtins.toJSON (lib.mapAttrs (_: a: a.dark) apps);
        passAsFile = [ "apps" ];
      }
      ''
        python3 - <<'EOF'
        import configparser, json, os, shutil
        icons = [["utilities-terminal", "org.gnome.Console", "konsole"], ["system-file-manager", "org.gnome.Nautilus", "org.kde.dolphin"],
                 ["firefox"], ["chromium", "google-chrome"], ["emacs"], ["preferences-system", "org.gnome.Settings", "systemsettings"],
                 ["accessories-calculator", "org.gnome.Calculator"], ["multimedia-volume-control", "org.pulseaudio.pavucontrol"]]
        root = "${appThemes}/share/icons"
        def lookup(theme, name, seen):
            if theme in seen or not os.path.isdir(os.path.join(root, theme)):
                return None
            seen.add(theme)
            ini = configparser.ConfigParser(interpolation=None, strict=False)
            ini.read(os.path.join(root, theme, "index.theme"))
            best = None
            for d in ini.get("Icon Theme", "Directories", fallback="").split(","):
                d = d.strip()
                size = 1000 if "scalable" in d else ini.getint(d, "Size", fallback=0) if ini.has_section(d) else 0
                for ext in ("svg", "png"):
                    f = os.path.join(root, theme, d, f"{name}.{ext}")
                    if os.path.exists(f) and size <= 1000 and (best is None or size > best[0]):
                        best = (size, f)
            if best:
                return best[1]
            for parent in ini.get("Icon Theme", "Inherits", fallback="").split(","):
                if parent.strip() and parent.strip() != "hicolor":
                    found = lookup(parent.strip(), name, seen)
                    if found:
                        return found
            return None
        out = {}
        for app, theme in json.load(open(os.environ["appsPath"])).items():
            os.makedirs(os.path.join(os.environ["out"], app))
            out[app] = []
            for names in icons:
                name = names[0]
                f = next(filter(None, (lookup(theme, n, set()) for n in names)), None)
                if f:
                    dest = os.path.join(os.environ["out"], app, name + os.path.splitext(f)[1])
                    shutil.copyfile(f, dest)
                    out[app].append(dest)
        json.dump(out, open(os.path.join(os.environ["out"], "previews.json"), "w"))
        EOF
      '';

  # every pack's icons by name ({ pack: { title, family, weight, font, tags,
  # bar, glyphs: { name: codepoint } } }, bar: [{ name, title, tabler }]), read
  # from the fonts; the build fails if a pack names an icon its font lacks
  index =
    pkgs.runCommand "icon-index"
      {
        nativeBuildInputs = [ (pkgs.python3.withPackages (p: [ p.fonttools ])) ];
        bar = builtins.toJSON bar;
        tablerNames = "${noctalia}/share/noctalia/assets/fonts/tabler.json";
        packs = builtins.toJSON (
          lib.mapAttrs (_: p: {
            inherit (p)
              title
              family
              weight
              tags
              bar
              ;
            path = "${p.package}";
            names = p.names or null;
            inherit (p) file;
          }) packs
        );
        passAsFile = [
          "packs"
          "bar"
        ];
      }
      ''
        python3 - <<'EOF'
        import json, os, sys
        from fontTools.ttLib import TTFont
        packs = json.load(open(os.environ["packsPath"]))
        bar = json.load(open(os.environ["barPath"]))
        tabler = {k: int(v["codepoint"][2:], 16) for k, v in json.load(open(os.environ["tablerNames"])).items()}
        out, bad = {}, []
        for name, p in packs.items():
            font = next(os.path.join(d, f) for d, _, fs in os.walk(p.pop("path")) for f in fs if f == p["file"])
            glyphs = {}
            tt = TTFont(font, lazy=True)
            families = {str(n) for n in tt["name"].names if n.nameID in (1, 16)}
            if p["family"] not in families:
                bad.append(f"{name}: family '{p['family']}' is not one of {sorted(families)}")
            names = p.pop("names")
            if names:
                glyphs = {k: int(v["codepoint"][2:], 16) for k, v in json.load(open(names)).items()}
            else:
                for cp, glyph in tt.getBestCmap().items():
                    if cp >= 0xE000 and glyph not in glyphs:
                        glyphs[glyph] = cp
            bad += [f"{name}: tag {t}: no icon '{g}'" for t, g in p["tags"].items() if g not in glyphs]
            bad += [f"{name}: bar {b}: no icon '{g}'" for b, g in p["bar"].items() if g not in glyphs]
            del p["file"]
            out[name] = dict(p, font=font, glyphs=glyphs)
        # noctalia's aliases (volume-high...) are in its code: these draw the Tabler icon
        alias = {"caffeine-on": "mug-filled", "caffeine-off": "mug", "memory": "cpu", "cpu-usage": "brand-speedtest",
                 "storage": "database", "volume-high": "volume", "volume-low": "volume-2", "volume-mute": "volume-off",
                 "battery-0": "battery", "battery-plugged": "battery-charging-2"}
        for b in bar:
            b["tabler"] = tabler.get(alias.get(b["name"], b["name"]), 0)
            if not b["tabler"]:
                bad.append(f"bar {b['name']}: not a Tabler icon")
        if bad:
            sys.exit("\n".join(bad))
        json.dump({"packs": out, "bar": bar}, open(os.environ["out"], "w"), sort_keys=True)
        EOF
      '';
}
