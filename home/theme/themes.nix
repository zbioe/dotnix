# Themes available to `theme` (home/theme) and to the boot screens
# (modules/theme-boot.nix): base16 schemes per mode, optional Doom theme.
{ pkgs }:
let
  schemeFile = name: "${pkgs.base16-schemes}/share/themes/${name}.yaml";

  kanagawaLotus =
    palette "Kanagawa Lotus" "Tommaso Laurenzi"
      "f2ecbc e7dba0 c9cbd1 8a8980 716e61 545464 43436c 1f1f28 c84053 cc6d00 77713f 6f894e 597b75 4d699b 624c83 b35b79";

  # inline palette: base00..base0F as one string, taken from the upstream
  # theme where base16-schemes has none (or a broken/outdated port)
  palette =
    scheme: author: colors:
    {
      inherit scheme author;
    }
    // builtins.listToAttrs (
      pkgs.lib.imap0 (i: color: {
        name = "base0${pkgs.lib.toHexString i}";
        value = color;
      }) (pkgs.lib.splitString " " colors)
    );

  # Modus (Emacs' built-in modus-themes): ANSI-like slots follow Modus'
  # semantic colors, so the colorblind variants keep their error/added hues
  modus = variant: colors: palette "Modus ${variant}" "Protesilaos Stavrou" colors;
in
{
  gruvbox = {
    schemes.dark = schemeFile "gruvbox-dark-medium";
    schemes.light = schemeFile "gruvbox-light-medium";
    emacs = {
      dark = "doom-gruvbox";
      light = "doom-gruvbox-light";
    };
  };
  solarized = {
    schemes.dark = schemeFile "solarized-dark";
    schemes.light = schemeFile "solarized-light";
    emacs = {
      dark = "doom-solarized-dark";
      light = "doom-solarized-light";
    };
  };
  nord = {
    schemes.dark = schemeFile "nord";
    schemes.light = schemeFile "nord-light";
    emacs = {
      dark = "doom-nord";
      light = "doom-nord-light";
    };
  };
  # acme/rio palette; not in base16-schemes
  plan9 = {
    schemes.light = {
      scheme = "Plan 9";
      author = "acme/rio colors";
      base00 = "ffffea"; # acme body
      base01 = "eaffff"; # tag
      base02 = "eeee9e"; # selection
      base03 = "99994c"; # borders, scrollbar
      base04 = "55553a";
      base05 = "000000";
      base06 = "1c1c1c";
      base07 = "000000";
      base08 = "aa0000";
      base09 = "b85c00";
      base0A = "8f8f00";
      base0B = "006600";
      base0C = "007777";
      base0D = "000099";
      base0E = "770077";
      base0F = "6b4f2a";
    };
    schemes.dark = {
      scheme = "Plan 9 Dark";
      author = "acme/rio colors, inverted";
      base00 = "1c1c14";
      base01 = "2a2a1f";
      base02 = "4a4a2e";
      base03 = "77774a";
      base04 = "b4b4a0";
      base05 = "ffffea";
      base06 = "eaffff";
      base07 = "ffffff";
      base08 = "e06060";
      base09 = "e0a050";
      base0A = "eeee9e";
      base0B = "7fbf7f";
      base0C = "9eeeee";
      base0D = "8888cc";
      base0E = "cc88cc";
      base0F = "b8a070";
    };
  };
  catppuccin = {
    schemes.dark = schemeFile "catppuccin-mocha";
    schemes.light = schemeFile "catppuccin-latte";
  };
  tokyo-night = {
    schemes.dark = schemeFile "tokyo-night-dark";
    schemes.light = schemeFile "tokyo-night-light";
    emacs.dark = "doom-tokyo-night";
    emacs.light = null;
  };
  rose-pine = {
    schemes.dark = schemeFile "rose-pine";
    schemes.light = schemeFile "rose-pine-dawn";
  };
  one = {
    schemes.dark = schemeFile "onedark";
    schemes.light = schemeFile "one-light";
    emacs = {
      dark = "doom-one";
      light = "doom-one-light";
    };
  };

  catppuccin-macchiato = {
    schemes.dark = schemeFile "catppuccin-macchiato";
    schemes.light = schemeFile "catppuccin-latte";
  };
  catppuccin-frappe = {
    schemes.dark = schemeFile "catppuccin-frappe";
    schemes.light = schemeFile "catppuccin-latte";
  };

  # AAA (>= 7:1) by design; tinted for everyday, plus the CVD variants
  modus = {
    schemes.dark = modus "Vivendi Tinted" "0d0e1c 1d2235 555a66 76797f 989898 ffffff ffffff ffffff ff5f59 ff6b55 d0bc00 44bc44 00d3d0 2fafff b6a0ff ff9f80";
    schemes.light = modus "Operandi Tinted" "fbf7f0 efe9dd c2bcb5 8e8a87 595959 000000 000000 000000 a60000 972500 6f5500 006800 005e8b 0031a9 531ab6 7f0000";
    emacs = {
      dark = "modus-vivendi-tinted";
      light = "modus-operandi-tinted";
    };
  };
  modus-deuteranopia = {
    schemes.dark = modus "Vivendi Deuteranopia" "000000 1e1e1e 5a5a5a 797979 989898 ffffff ffffff ffffff ffa00f ffa00f cabf00 2fafff 00d3d0 2fafff b6a0ff d8af7a";
    schemes.light = modus "Operandi Deuteranopia" "ffffff f2f2f2 bdbdbd 8b8b8b 595959 000000 000000 000000 973300 973300 695500 0031a9 005e8b 0031a9 531ab6 77492f";
    emacs = {
      dark = "modus-vivendi-deuteranopia";
      light = "modus-operandi-deuteranopia";
    };
  };
  modus-tritanopia = {
    schemes.dark = modus "Vivendi Tritanopia" "000000 1e1e1e 5a5a5a 797979 989898 ffffff ffffff ffffff ff6740 ff6740 feacd0 00d3d0 00d3d0 2fafff ff6f9f ff9070";
    schemes.light = modus "Operandi Tritanopia" "ffffff f2f2f2 bdbdbd 8b8b8b 595959 000000 000000 000000 b21100 b21100 721045 005e8b 005e8b 0031a9 a0132f 702000";
    emacs = {
      dark = "modus-vivendi-tritanopia";
      light = "modus-operandi-tritanopia";
    };
  };

  # Solarized redone in CIELAB; dark/light, and black/white for more contrast
  selenized = {
    schemes.dark = schemeFile "selenized-dark";
    schemes.light = schemeFile "selenized-light";
  };
  selenized-contrast = {
    schemes.dark = schemeFile "selenized-black";
    schemes.light = schemeFile "selenized-white";
  };

  # dark from base16-schemes, light from sainnhe/everforest (same accents)
  everforest = {
    schemes.dark = schemeFile "everforest-dark-medium";
    schemes.light =
      palette "Everforest Light Medium" "Sainnhe Park"
        "fdf6e3 f4f0d9 e6e2cc 939f91 829181 5c6a72 475258 2d353b f85552 f57d26 dfa000 8da101 35a77c 3a94c5 df69ba 829181";
  };
  everforest-hard = {
    schemes.dark = schemeFile "everforest-dark-hard";
    schemes.light =
      palette "Everforest Light Hard" "Sainnhe Park"
        "fffbef f8f5e4 edeada 939f91 829181 5c6a72 475258 2d353b f85552 f57d26 dfa000 8da101 35a77c 3a94c5 df69ba 829181";
  };
  everforest-soft = {
    schemes.dark = schemeFile "everforest-dark-soft";
    schemes.light =
      palette "Everforest Light Soft" "Sainnhe Park"
        "f3ead3 eae4ca ddd8be 939f91 829181 5c6a72 475258 2d353b f85552 f57d26 dfa000 8da101 35a77c 3a94c5 df69ba 829181";
  };

  gruvbox-material = {
    schemes.dark = schemeFile "gruvbox-material-dark-medium";
    schemes.light = schemeFile "gruvbox-material-light-medium";
  };

  flexoki = {
    schemes.dark = schemeFile "flexoki-dark";
    schemes.light = schemeFile "flexoki-light";
  };

  # wave / dragon; light is lotus (from kanagawa.nvim, not in base16-schemes)
  kanagawa = {
    schemes.dark = schemeFile "kanagawa";
    schemes.light = kanagawaLotus;
  };
  kanagawa-dragon = {
    schemes.dark = schemeFile "kanagawa-dragon";
    schemes.light = kanagawaLotus;
  };

  # upstream Primer (github-nvim-theme palettes), not the old base16 ports
  github = {
    schemes.dark =
      palette "GitHub Dark" "Primer"
        "0d1117 161b22 17335a 6e7681 7d8590 e6edf3 e6edf3 ffffff f85149 db6d28 d29922 3fb950 76e3ea 2f81f7 a371f7 db61a2";
    schemes.light =
      palette "GitHub Light" "Primer"
        "ffffff f6f8fa dae9f9 6e7781 32383f 1f2328 1f2328 000000 d1242f bc4c00 9a6700 1a7f37 1b7c83 0969da 8250df bf3989";
  };
  github-high-contrast = {
    schemes.dark =
      palette "GitHub Dark High Contrast" "Primer"
        "0a0c10 272b33 1a3858 9ea7b3 d9dee3 f0f3f6 f0f3f6 ffffff ff6a69 e7811d e09b13 09b43a 76e3ea 409eff b780ff ef6eb1";
    schemes.light =
      palette "GitHub Light High Contrast" "Primer"
        "ffffff e7ecf0 cddbf0 66707b 20252c 010409 010409 000000 d1242f 873800 744500 055d20 1b7c83 0349b4 622cbc 971368";
  };
  # red/green become orange/blue
  github-colorblind = {
    schemes.dark =
      palette "GitHub Dark Colorblind" "Primer"
        "0d1117 161b22 2f547f 6e7681 8b949e c9d1d9 c9d1d9 ffffff d47616 d47616 d29922 58a6ff 76e3ea 58a6ff a371f7 db61a2";
    schemes.light =
      palette "GitHub Light Colorblind" "Primer"
        "ffffff f6f8fa dae9f9 6e7781 32383f 1b1f24 1b1f24 000000 b35900 b35900 9a6700 0969da 1b7c83 0969da 8250df bf3989";
  };

  # from zenbones.nvim's terminal palettes (the base16 port maps ANSI slots)
  zenbones = {
    schemes.dark =
      palette "Zenbones Dark" "Michael Chris Lopez"
        "1c1917 2c2c2c 3d4042 646464 888f94 b4bdc3 c7ced2 dadee1 de6e7c d68c67 b77e64 819b69 66a5ad 6099c0 b279a7 cf86c1";
    schemes.light =
      palette "Zenbones Light" "Michael Chris Lopez"
        "f0edec dee3e8 cbd9e3 8f9091 4f5e68 2c363c 21282d 161b1e a8334c 803d1c 944927 4f6c31 3b8992 286486 88507d 7b3b70";
  };
  zenwritten = {
    schemes.dark =
      palette "Zenwritten Dark" "Michael Chris Lopez"
        "191919 2c2c2c 404040 666364 8e8e8e bbbbbb cccccc dddddd de6e7c d68c67 b77e64 819b69 66a5ad 6099c0 b279a7 cf86c1";
    schemes.light =
      palette "Zenwritten Light" "Michael Chris Lopez"
        "eeeeee e2e2e2 d7d7d7 919090 5c5c5c 353535 282828 1a1a1a a8334c 803d1c 944927 4f6c31 3b8992 286486 88507d 7b3b70";
  };

  ayu = {
    schemes.dark = schemeFile "ayu-dark";
    schemes.light = schemeFile "ayu-light";
    emacs = {
      dark = "doom-ayu-dark";
      light = "doom-ayu-light";
    };
  };
  ayu-mirage = {
    schemes.dark = schemeFile "ayu-mirage";
    schemes.light = schemeFile "ayu-light";
    emacs = {
      dark = "doom-ayu-mirage";
      light = "doom-ayu-light";
    };
  };

  # dark only
  zenburn = {
    schemes.dark = schemeFile "zenburn";
    emacs.dark = "doom-zenburn";
  };
}
