# The browsers' own pages (settings, history, extensions, ...) in the
# palette, so they follow `theme` live like the rest. No extension may touch
# them, but they all load chrome://resources/css/md_colors.css from
# resources.pak and get the browser's colors from chrome://theme/colors.css
# (the GTK theme's, or Brave's theme extension's): webui.css, appended to
# md_colors.css, maps one onto the other.
#
# The browser finds resources.pak next to its real executable, so the
# executable is copied (hardlinked back by the store optimiser) beside the
# patched pak; everything else stays a symlink.
{
  lib,
  runCommand,
  python3,
}:
let
  python = python3.withPackages (p: [ p.brotli ]);
  patchedPak =
    pak: css:
    runCommand (baseNameOf pak) { } ''
      ${python}/bin/python3 ${./patch-pak.py} ${pak} $out ${lib.concatMapStringsSep " " (p: "${p}") css}
    '';

  # pkg as symlinks; its launchers and desktop files are rewritten from
  # pkg (and each `from` pair) to the new paths. `extra` runs before that,
  # `post` after.
  relink =
    {
      pkg,
      from ? [ ],
      extra ? "",
      post ? "",
    }:
    runCommand "${pkg.name}-themed" { } ''
      cp -rs --no-preserve=mode ${pkg} $out
      ${extra}
      for f in $(find $out/bin $out/share/applications -type l 2>/dev/null); do
        target=$(readlink -f "$f")
        if grep -qI -e ${pkg} ${lib.concatMapStrings (p: "-e ${p.old} ") from}"$target"; then
          rm "$f"
          sed -e "s|${pkg}|$out|g" ${
            lib.concatMapStrings (p: "-e 's|${p.old}|${p.new}|g' ") from
          }"$target" > "$f"
          chmod --reference="$target" "$f"
        fi
      done
      ${post}
    '';

  # DIR/BINARY (and DIR/COPY: launchers that find the binary through
  # `readlink -f` on themselves) copied beside a patched DIR/resources.pak
  # (and DIR/PAKS, the browser's own packs, for their fixed whites); CSS is
  # appended to the pages' shared stylesheets
  rebase =
    {
      pkg,
      dir,
      binary,
      copy ? [ ],
      paks ? [ ],
      css ? [ ./webui.css ],
      extra ? "",
      post ? "",
    }:
    relink {
      inherit pkg post;
      extra = ''
        for f in ${lib.concatStringsSep " " ([ binary ] ++ copy)}; do
          rm $out/${dir}/$f
          cp ${pkg}/${dir}/$f $out/${dir}/$f
        done
        rm $out/${dir}/resources.pak
        cp ${patchedPak "${pkg}/${dir}/resources.pak" css} $out/${dir}/resources.pak
        ${lib.concatMapStrings (p: ''
          rm $out/${dir}/${p}
          cp ${patchedPak "${pkg}/${dir}/${p}" (css ++ [ "--whites-only" ])} $out/${dir}/${p}
        '') paks}
        ${extra}
      '';
    };
in
{
  # wrapper (bin/chromium) and the browser it runs (chromium.browser)
  chromium =
    chromium:
    let
      browser = rebase {
        pkg = chromium.browser;
        dir = "libexec/chromium";
        binary = "chromium";
      };
    in
    relink {
      pkg = chromium;
      from = [
        {
          old = chromium.browser;
          new = browser;
        }
      ];
    };

  # Brave on its theme extension (pkgs/brave-theme): pages in that theme's
  # colors (brave.css), PRELAUNCH run by the launcher first
  brave =
    {
      prelaunch ? null,
    }:
    brave:
    rebase {
      pkg = brave;
      dir = "opt/brave.com/brave";
      binary = "brave";
      copy = [ "brave-browser" ];
      paks = [ "brave_resources.pak" ];
      css = [
        ./webui.css
        ./brave.css
      ];
      # was relative; cp -rs made it point into the original package
      extra = "ln -sfn ../opt/brave.com/brave/brave-browser $out/bin/.brave-wrapped";
      post = lib.optionalString (prelaunch != null) ''
        sed -i '1a ${prelaunch} "$0" || true' $out/bin/brave
      '';
    };
}
