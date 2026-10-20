# Fonts `theme font` can pick (home/theme/fonts), shared by NixOS and home: all
# of them are installed, so any choice applies live
{ pkgs }:
let
  inherit (pkgs) lib;
  font = name: package: { inherit name package; };
in
rec {
  # families per role; `term` (terminals) picks from `mono`
  roles = {
    ui = [
      (font "Atkinson Hyperlegible Next" pkgs.atkinson-hyperlegible-next)
      (font "Inter" pkgs.inter)
      (font "Noto Sans" pkgs.noto-fonts)
      (font "IBM Plex Sans" pkgs.ibm-plex)
      (font "Source Sans 3" pkgs.source-sans)
      (font "Ubuntu Sans" pkgs.ubuntu-sans)
      (font "Fira Sans" pkgs.fira-sans)
      (font "Lexend" pkgs.lexend)
      (font "Roboto" pkgs.roboto)
      (font "Geist" pkgs.geist-font)
      (font "DejaVu Sans" pkgs.dejavu_fonts)
    ];
    serif = [
      (font "Noto Serif" pkgs.noto-fonts)
      (font "Source Serif 4" pkgs.source-serif)
      (font "IBM Plex Serif" pkgs.ibm-plex)
      (font "DejaVu Serif" pkgs.dejavu_fonts)
    ];
    mono = [
      (font "JetBrains Mono" pkgs.jetbrains-mono)
      (font "Atkinson Hyperlegible Mono" pkgs.atkinson-hyperlegible-mono)
      (font "Noto Sans Mono" pkgs.noto-fonts)
      (font "IBM Plex Mono" pkgs.ibm-plex)
      (font "Fira Code" pkgs.fira-code)
      (font "Source Code Pro" pkgs.source-code-pro)
      (font "Ubuntu Sans Mono" pkgs.ubuntu-sans-mono)
      (font "Iosevka" pkgs.iosevka)
      (font "CommitMono" pkgs.commit-mono)
      (font "Cascadia Code" pkgs.cascadia-code)
      (font "Victor Mono" pkgs.victor-mono)
      (font "Hack" pkgs.hack-font)
      (font "DejaVu Sans Mono" pkgs.dejavu_fonts)
    ];
    emoji = [
      (font "Noto Color Emoji" pkgs.noto-fonts-color-emoji)
      (font "Twitter Color Emoji" pkgs.twemoji-color-font)
      (font "OpenMoji Color" pkgs.openmoji-color)
      (font "Noto Emoji" pkgs.noto-fonts-monochrome-emoji)
    ];
  };

  # sizes in points: ui (GTK, Qt, shell), mono (code in apps), term (terminals), editor (Emacs)
  default = {
    ui = "Atkinson Hyperlegible Next";
    serif = "Noto Serif";
    mono = "JetBrains Mono";
    term = "JetBrains Mono";
    emoji = "Noto Color Emoji";
    ui_size = "12";
    mono_size = "12";
    term_size = "8";
    editor_size = "15";
  };

  # families only: sizes stay as they are
  presets = {
    default = {
      inherit (default)
        ui
        serif
        mono
        term
        emoji
        ;
    };
    atkinson = {
      ui = "Atkinson Hyperlegible Next";
      serif = "Noto Serif";
      mono = "Atkinson Hyperlegible Mono";
      term = "Atkinson Hyperlegible Mono";
    };
    noto = {
      ui = "Noto Sans";
      serif = "Noto Serif";
      mono = "Noto Sans Mono";
      term = "Noto Sans Mono";
    };
    plex = {
      ui = "IBM Plex Sans";
      serif = "IBM Plex Serif";
      mono = "IBM Plex Mono";
      term = "IBM Plex Mono";
    };
    inter = {
      ui = "Inter";
      serif = "Source Serif 4";
      mono = "JetBrains Mono";
      term = "JetBrains Mono";
    };
    dejavu = {
      ui = "DejaVu Sans";
      serif = "DejaVu Serif";
      mono = "DejaVu Sans Mono";
      term = "DejaVu Sans Mono";
    };
  };

  # whatever the chosen fonts lack: every script, CJK, icons
  fallback = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    nerd-fonts.symbols-only
    material-icons
  ];

  packages = lib.unique (map (f: f.package) (lib.concatLists (lib.attrValues roles)) ++ fallback);

  # the default's entry of a role ({ name, package }), for what can't switch live (boot screens)
  defaultOf = role: lib.findFirst (f: f.name == default.${role}) null roles.${role};
}
