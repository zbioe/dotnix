# nix flake check: every family of the catalog is in its package, defaults and
# presets name catalog fonts, and the installed fonts leave no text as tofu
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
  fontsConf = pkgs.makeFontsConf { fontDirectories = catalog.packages; };
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
    touch $out
  ''
