# NixOS snowflake in the colors of one base16 scheme: lambdas in the
# opposite-mode color (base05) and the theme's blue muted towards the
# background (57%: the teal of assets/wallpaper-gruvbox.jpg). Used for the
# wallpaper (home/theme) and the boot screens (modules/theme-boot.nix).
{
  pkgs,
  lib,
  colors,
}:
let
  c = colors.withHashtag;

  # mix of two palette colors, ratio 0..1 towards `to`: "#rrggbb"
  mix =
    from: to: ratio:
    let
      channel =
        ch:
        let
          a = lib.toInt colors."${from}-rgb-${ch}";
          b = lib.toInt colors."${to}-rgb-${ch}";
          n = builtins.floor (a + (b - a) * ratio + 0.5);
        in
        lib.fixedWidthString 2 "0" (lib.toLower (lib.toHexString n));
    in
    "#"
    + lib.concatMapStrings channel [
      "r"
      "g"
      "b"
    ];

  logoSvg = pkgs.runCommandLocal "nix-snowflake.svg" { } ''
    sed -e 's/fill:url(#linearGradient4328)/fill:${mix "base00" "base0D" 0.57}/' \
        -e 's/fill:url(#linearGradient4330)/fill:${c.base05}/' \
        ${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg > $out
  '';

  render =
    name: script:
    pkgs.runCommandLocal name {
      nativeBuildInputs = [
        pkgs.resvg
        pkgs.imagemagick
      ];
    } script;
in
{
  inherit mix;

  # transparent logo, `size` px wide
  logo =
    size: render "nix-snowflake-${toString size}.png" "resvg -w ${toString size} ${logoSvg} $out";

  # 1920x1080: logo centered on the terminal background
  wallpaper = render "wallpaper.png" ''
    resvg -w 575 ${logoSvg} logo.png
    magick -size 1920x1080 xc:'${c.base00}' logo.png -gravity center -composite $out
  '';
}
