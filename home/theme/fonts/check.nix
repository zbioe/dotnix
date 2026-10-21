# nix flake check: every family of the catalog is in its package, defaults and
# presets name catalog fonts, the installed fonts leave no text as tofu, and
# whatever the chosen font, the setup's icons come from Symbols Nerd Font
{ pkgs }:
let
  inherit (pkgs) lib;
  catalog = import ./catalog.nix { inherit pkgs; };
  inRole = role: name: lib.any (f: f.name == name) catalog.roles.${role};
  roleOf = key: if key == "term" then "mono" else key;
  named = lib.filterAttrs (k: _: !(lib.hasSuffix "_size" k));
  bad = lib.flatten (
    lib.mapAttrsToList
      (
        set: values:
        lib.mapAttrsToList (key: name: lib.optional (!inRole (roleOf key) name) "${set}.${key}: ${name}") (
          named values
        )
      )
      (
        {
          default = catalog.default;
        }
        // lib.mapAttrs' (n: lib.nameValuePair "presets.${n}") catalog.presets
      )
  );
  # as on the system: the catalog's fonts and fontconfig's own rules (50-user
  # reads $XDG_CONFIG_HOME/fontconfig, where `theme font` writes)
  fontsConf = pkgs.writeText "fonts.conf" ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      ${lib.concatMapStrings (p: "<dir>${p}/share/fonts</dir>\n") catalog.packages}
      <include>${pkgs.fontconfig.out}/etc/fonts/conf.d</include>
    </fontconfig>
  '';
  # scripts, symbols, emoji old and new, and the glyphs the setup itself shows
  sample = "ãçéőŀ ΑλΩ Жюя שלום مرحبا नमस्ते สวัสดี 中文 日本語 한국어 ქართ Հայ தமிழ் বাংলা አማ བོད ∀∑⟹𝔸ℕ ⇄ ╭─╮ ⠿ ₿₹€ ⌘⏎␣ ♫♞ ✓✗ … — “” ⚠ ⚡ 😀🫠🫨🪿🫩🥲👍 󰖔󰖨󱢢";
in
assert lib.assertMsg (
  bad == [ ]
) "fonts outside the catalog roles: ${lib.concatStringsSep ", " bad}";
pkgs.runCommand "fonts-check"
  {
    nativeBuildInputs = [
      pkgs.fontconfig
      pkgs.python3
    ];
    FONTCONFIG_FILE = fontsConf;
    sample = sample;
    # the icons the setup shows: its private use area characters
    icons = lib.concatMapStrings builtins.readFile [
      ../../ui/noctalia.nix
      ../../ui/mango.nix
      ../default.nix
    ];
    ui = lib.concatMapStringsSep "\n" (f: f.name) catalog.roles.ui;
    mono = lib.concatMapStringsSep "\n" (f: f.name) catalog.roles.mono;
  }
  ''
    export HOME=$TMPDIR
    ${lib.concatMapStrings (f: ''
      FONTCONFIG_FILE=${
        pkgs.makeFontsConf { fontDirectories = [ f.package ]; }
      } fc-list --format '%{family}\n' | tr ',' '\n' | grep -xF ${lib.escapeShellArg f.name} >/dev/null ||
        { echo "${f.name}: not a family of ${f.package.name}"; exit 1; }
    '') (lib.unique (lib.concatLists (lib.attrValues catalog.roles)))}
    python3 - <<'EOF'
    import os, subprocess
    missing = []
    for c in sorted(set(os.environ["sample"])):
        if c.isspace():
            continue
        out = subprocess.run(["fc-list", f":charset={ord(c):x}", "family"], capture_output=True, text=True).stdout
        if not out.strip():
            missing.append(f"{c} U+{ord(c):04X}")
    if missing:
        raise SystemExit("tofu: " + ", ".join(missing))
    EOF

    # each font as `theme font` writes it (font.sh), where the user's config is read
    state=$TMPDIR
    source ${./font.sh}
    export XDG_CONFIG_HOME=$TMPDIR/config
    mkdir -p $XDG_CONFIG_HOME/fontconfig/conf.d
    python3 - <<'EOF'
    import os, subprocess
    icons = sorted({c for c in os.environ["icons"] if 0xE000 <= ord(c) <= 0xF8FF or ord(c) >= 0xF0000})
    conf = os.path.join(os.environ["XDG_CONFIG_HOME"], "fontconfig/conf.d/60-theme-fonts.conf")
    bad = []
    for role in ("ui", "mono"):
        for family in os.environ[role].split("\n"):
            ui, mono = (family, "JetBrains Mono") if role == "ui" else ("Inter", family)
            xml = subprocess.run(["bash", "-c", 'source "$0"; font_fontconfig "$1" "Noto Serif" "$2" "Noto Color Emoji"',
                                  "${./font.sh}", ui, mono], capture_output=True, text=True, check=True).stdout
            open(conf, "w").write(xml)
            for c in icons:
                got = subprocess.run(["fc-match", f"{family}:charset={ord(c):x}", "family"],
                                     capture_output=True, text=True).stdout.split(",")[0].strip()
                # a font asked by name draws what it has (DejaVu Sans: U+F001)
                if not got.startswith("Symbols Nerd Font") and got != family:
                    bad.append(f"{family}: U+{ord(c):04X} from {got}")
    if bad:
        raise SystemExit("icons from the wrong font:\n  " + "\n  ".join(bad))
    print(f"{len(icons)} icons right with every ui and mono font")
    EOF
    touch $out
  ''
