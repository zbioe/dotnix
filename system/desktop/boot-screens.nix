# GRUB, Plymouth, the console and SDDM follow `theme`: every theme is prebuilt,
# and theme-boot hands the choice over through grubenv and /var/lib/theme.
# With Limine (Secure Boot) the kernel command line is sealed: theme-boot
# leaves the theme's name on the ESP and the initrd picks it from there.
{
  config,
  lib,
  pkgs,
  base16,
  ...
}:
let
  default = "gruvbox-dark";
  grub = config.dotnix.core.boot.loader == "grub";

  themes = import ../../home/theme/themes.nix { inherit pkgs; };
  # boot screens can't follow `theme font`: the catalog's defaults
  catalog = import ../../home/theme/fonts/catalog.nix { inherit pkgs; };
  fonts = {
    sansSerif = catalog.defaultOf "ui";
    monospace = catalog.defaultOf "mono";
    size = catalog.default.ui_size;
  };
  inherit (base16.lib { inherit pkgs lib; }) mkSchemeAttrs;

  variants = lib.concatLists (
    lib.mapAttrsToList (
      name: theme:
      lib.mapAttrsToList (mode: scheme: {
        id = "${name}-${mode}";
        colors = mkSchemeAttrs scheme;
      }) theme.schemes
    ) themes
  );
  ids = map (v: v.id) variants;

  pixel =
    color:
    pkgs.runCommandLocal "pixel.png" { } "${lib.getExe pkgs.imagemagick} xc:'${color}' png32:$out";

  # GRUB wants PFF2 fonts
  grubFont =
    font:
    pkgs.runCommand "${font.package.name}.pf2"
      {
        FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ font.package ]; };
      }
      ''
        font=$(${lib.getExe' pkgs.fontconfig "fc-match"} ${lib.escapeShellArg font.name} --format "%{file}")
        ${lib.getExe' pkgs.grub2 "grub-mkfont"} $font --output $out --size ${fonts.size}
      '';

  # GRUB theme, one per variant
  grubTheme =
    { id, colors }:
    let
      c = colors.withHashtag;
    in
    pkgs.runCommandLocal "grub-theme-${id}"
      {
        themeTxt = ''
          desktop-image: "background.png"
          desktop-image-scale-method: "crop"
          desktop-color: "${c.base00}"

          title-text: ""

          terminal-left: "10%"
          terminal-top: "20%"
          terminal-width: "80%"
          terminal-height: "60%"

          + progress_bar {
            left = 25%
            top = 80%+20
            width = 50%
            height = 30

            id = "__timeout__"
            show_text = true
            font = "${fonts.sansSerif.name}"
            text = "@TIMEOUT_NOTIFICATION_MIDDLE@"

            border_color = "${c.base00}"
            bg_color = "${c.base00}"
            fg_color = "${c.base0B}"
            text_color = "${c.base05}"
          }

          + boot_menu {
            left = 25%
            top = 20%
            width = 50%
            height = 60%
            menu_pixmap_style = "background_*.png"

            item_height = 40
            item_icon_space = 8
            item_spacing = 0
            item_padding = 0
            item_font = "${fonts.sansSerif.name}"
            item_color = "${c.base05}"

            selected_item_color = "${c.base01}"
            selected_item_pixmap_style = "selection_*.png"
          }
        '';
        passAsFile = [ "themeTxt" ];
      }
      ''
        mkdir $out
        cp $themeTxtPath $out/theme.txt
        cp ${pixel c.base00} $out/background.png
        cp ${pixel c.base01} $out/background_c.png
        cp ${pixel c.base0B} $out/selection_c.png
      '';

  # /boot/theme: the default at the top (what NixOS sets), every theme in variants/
  grubThemes = pkgs.runCommandLocal "grub-themes" { } ''
    mkdir -p $out/variants
    cp -r ${grubTheme (lib.findFirst (v: v.id == default) null variants)}/. $out/
    chmod -R u+w $out
    ${lib.concatMapStrings (v: ''
      cp -r ${grubTheme v} $out/variants/${v.id}
    '') variants}
    cp ${grubFont fonts.sansSerif} $out/sans_serif.pf2
  '';

  # plymouth script (home/theme/plymouth.nix) with the theme's snowflake as the spinning logo
  plymouthTheme =
    { id, colors }:
    let
      art = import ../../home/theme/art.nix { inherit pkgs lib colors; };
      script = import ../../home/theme/plymouth.nix {
        inherit lib colors;
        logoAnimated = true;
      };
      dir = "$out/share/plymouth/themes/nix-${id}";
    in
    pkgs.runCommandLocal "plymouth-theme-nix-${id}" { } ''
      mkdir -p ${dir}
      # transparent border so the rotating logo is not clipped
      ${lib.getExe pkgs.imagemagick} ${art.logo 256} -background transparent \
        -bordercolor transparent -border 42% ${dir}/logo.png
      cp ${script} ${dir}/nix-${id}.script
      cat > ${dir}/nix-${id}.plymouth <<EOF
      [Plymouth Theme]
      Name=nix-${id}
      ModuleName=script
      [script]
      ImageDir=${dir}
      ScriptFile=${dir}/nix-${id}.script
      EOF
    '';

  sddmTheme =
    { colors, ... }:
    pkgs.where-is-my-sddm-theme.override {
      themeConfig.General = with colors.withHashtag; {
        hideCursor = true;
        backgroundFill = base00;
        basicTextColor = base05;
        passwordCursorColor = base0B;
        passwordCharacter = "•";
        passwordInputWidth = "1";
        passwordFontSize = 62;
      };
    };

  # console palette for setvtrgb: red, green, blue rows
  vtrgb =
    { id, colors }:
    let
      order = [
        "base00"
        "base08"
        "base0B"
        "base0A"
        "base0D"
        "base0E"
        "base0C"
        "base05"
        "base03"
        "base08"
        "base0B"
        "base0A"
        "base0D"
        "base0E"
        "base0C"
        "base07"
      ];
      row = ch: lib.concatMapStringsSep "," (b: colors."${b}-rgb-${ch}") order;
    in
    pkgs.writeText "vtrgb-${id}" ''
      ${row "r"}
      ${row "g"}
      ${row "b"}
    '';

  # the same palette as kernel parameters: vt.default_{red,grn,blu}=0xRR,...
  vtKernel =
    { colors, ... }:
    let
      order = [
        "base00"
        "base08"
        "base0B"
        "base0A"
        "base0D"
        "base0E"
        "base0C"
        "base05"
        "base03"
        "base08"
        "base0B"
        "base0A"
        "base0D"
        "base0E"
        "base0C"
        "base07"
      ];
    in
    ch: lib.concatMapStringsSep "," (b: "0x" + colors."${b}-hex-${ch}") order;
  defaultVariant = lib.findFirst (v: v.id == default) null variants;

  index = pkgs.linkFarm "boot-themes" (
    lib.concatMap (v: [
      {
        name = "${v.id}/vtrgb";
        path = vtrgb v;
      }
      {
        name = "${v.id}/grubenv";
        path = pkgs.writeText "grubenv-${v.id}" ''
          nix_theme=${v.id}
          nix_bg=${v.colors.base00}
          nix_vt_red=${vtKernel v "r"}
          nix_vt_grn=${vtKernel v "g"}
          nix_vt_blu=${vtKernel v "b"}
        '';
      }
      {
        name = "${v.id}/sddm";
        path = "${sddmTheme v}/share/sddm/themes/where_is_my_sddm_theme";
      }
    ]) variants
  );

  # Limine: the name theme-boot left on the ESP (unsigned, so only one Nix
  # built is taken), for the console palette and plymouth
  esp = config.fileSystems."/boot".device;
  vtrgbs = pkgs.linkFarm "boot-vtrgb" (
    map (v: {
      name = v.id;
      path = vtrgb v;
    }) variants
  );
  # (the initrd copies these binaries, not the scripts' closures)
  initrdBins = {
    mount = "${pkgs.util-linux}/bin/mount";
    umount = "${pkgs.util-linux}/bin/umount";
    mkdir = "${pkgs.coreutils}/bin/mkdir";
    udevadm = "${config.boot.initrd.systemd.package}/bin/udevadm";
    setvtrgb = "${pkgs.kbd}/bin/setvtrgb";
  };
  initrdTheme = pkgs.writeShellScript "dotnix-boot-theme" (
    with initrdBins;
    ''
      id=${default} chosen=""
      ${udevadm} wait --timeout=3 ${esp} || true
      ${mkdir} -p /run/dotnix/esp
      if ${mount} -t vfat -o ro,nosuid,nodev,noexec ${esp} /run/dotnix/esp; then
        [ -f /run/dotnix/esp/dotnix-theme ] && read -r -n 64 chosen < /run/dotnix/esp/dotnix-theme
        ${umount} /run/dotnix/esp
      fi
      case "$chosen" in
        ${lib.concatStringsSep "|" ids}) id=$chosen ;;
      esac
      echo "dotnix-boot-theme: $id"
      echo "$id" > /run/dotnix/boot-theme
      ${setvtrgb} ${vtrgbs}/"$id" || true
    ''
  );
  plymouthStart = pkgs.writeShellScript "plymouth-start-theme" ''
    id=${default}
    [ -r /run/dotnix/boot-theme ] && read -r id < /run/dotnix/boot-theme
    read -r line < /proc/cmdline
    cmdline=""
    for word in $line; do
      [[ $word == plymouth.splash=* ]] || cmdline+=" $word"
    done
    exec ${config.boot.plymouth.package}/sbin/plymouthd --mode=boot --pid-file=/run/plymouth/pid \
      --attach-to-session --kernel-command-line="$cmdline plymouth.splash=nix-$id"
  '';

  stateDir = "${config.users.users.${config.dotnix.core.user.name}.home}/.local/state/theme";

  sync = pkgs.writeShellApplication {
    name = "theme-boot";
    runtimeInputs = with pkgs; [
      coreutils
      kbd
    ];
    text = ''
      # `theme` writes the pair to boot in one go (name/mode: before it did)
      read_id() {
        if [ -s ${stateDir}/boot ]; then
          cat ${stateDir}/boot
        else
          echo "$(cat ${stateDir}/name 2>/dev/null)-$(cat ${stateDir}/mode 2>/dev/null)"
        fi
      }

      apply() {
        local id=$1
        # only names Nix built; anything else keeps the current choice
        case "$id" in
          ${lib.concatStringsSep "|" ids}) ;;
          *)
            echo "theme-boot: unknown theme '$id', keeping the current one"
            id=$(readlink /var/lib/theme/current 2>/dev/null | xargs -r basename)
            [ -n "$id" ] || id=${default}
            ;;
        esac

        ${
          if grub then
            ''
              # shellcheck disable=SC2046 # one name=value per line
              ${lib.getExe' pkgs.grub2 "grub-editenv"} /boot/grub/grubenv set $(cat ${index}/"$id"/grubenv)
              sync -f /boot/grub/grubenv
            ''
          else
            ''
              if [ "$(cat /boot/dotnix-theme 2>/dev/null)" != "$id" ]; then
                printf '%s\n' "$id" > /boot/dotnix-theme.tmp
                mv -f /boot/dotnix-theme.tmp /boot/dotnix-theme
                sync -f /boot/dotnix-theme
              fi
            ''
        }

        mkdir -p /var/lib/theme
        ln -sfn ${index}/"$id" /var/lib/theme/current.tmp
        mv -Tf /var/lib/theme/current.tmp /var/lib/theme/current
        ln -sfn /var/lib/theme/current/sddm /var/lib/theme/sddm/where_is_my_sddm_theme.tmp
        mv -Tf /var/lib/theme/sddm/where_is_my_sddm_theme.tmp /var/lib/theme/sddm/where_is_my_sddm_theme

        setvtrgb ${index}/"$id"/vtrgb || true
        echo "theme-boot: $id"
      }

      # a change that lands while this runs doesn't start it again (the path
      # unit drops it): go again until the state holds still
      for _ in 1 2 3 4 5; do
        id=$(read_id)
        apply "$id"
        [ "$(read_id)" = "$id" ] && break
      done
    '';
  };

  # the shutdown splash: the kernel command line still names the theme of
  # boot time, so hand plymouthd one with the theme active now. It starts
  # while the session is still stopping: until the compositor (or greeter)
  # lets go of the screen plymouth can't draw and falls back to text, so
  # wait for them first (at most 5s)
  shutdownSplash = pkgs.writeShellScript "plymouth-shutdown" ''
    # the state as it is now, even if a change never got synced
    ${lib.getExe sync} || true
    ${pkgs.coreutils}/bin/timeout 5 ${pkgs.procps}/bin/pidwait -x 'mango|sddm-greeter.*' || true
    id=$(${pkgs.coreutils}/bin/basename "$(${pkgs.coreutils}/bin/readlink /var/lib/theme/current)")
    cmdline=$(${pkgs.gnused}/bin/sed 's/plymouth\.splash=[^ ]*//' /proc/cmdline)
    exec ${config.boot.plymouth.package}/sbin/plymouthd --mode=shutdown --attach-to-session \
      --kernel-command-line="$cmdline plymouth.splash=nix-$id"
  '';
in
{
  options.dotnix.desktop.bootScreens.enable =
    lib.mkEnableOption "boot screens (GRUB, Plymouth, console, SDDM) following `theme`";

  config = lib.mkIf config.dotnix.desktop.bootScreens.enable {
    boot.loader.grub = lib.mkIf grub {
      theme = grubThemes;
      splashImage = pixel defaultVariant.colors.withHashtag.base00;
      backgroundColor = defaultVariant.colors.withHashtag.base00;
      font = toString (grubFont fonts.monospace);
      # runs after NixOS sets the default theme; load_env is already at the top
      extraConfig = ''
        if [ -n "$nix_theme" -a -f "($drive1)//theme/variants/$nix_theme/theme.txt" ]; then
          set theme=($drive1)//theme/variants/$nix_theme/theme.txt
          # the screen behind "Loading…" (NixOS set the default's splash)
          background_image --mode stretch ($drive1)//theme/variants/$nix_theme/background.png
        else
          set nix_theme=${default}
          set nix_vt_red=${vtKernel defaultVariant "r"}
          set nix_vt_grn=${vtKernel defaultVariant "g"}
          set nix_vt_blu=${vtKernel defaultVariant "b"}
          set nix_bg=${defaultVariant.colors.base00}
        fi
        # text area (e.g. "Loading kernel") uses the gfxterm background
        background_color "#$nix_bg"
        # set again so gfxterm repaints: without it the screen behind
        # "Loading…" stays white (or black) until plymouth starts
        set color_normal=light-gray/black
        export theme
        export nix_theme
        export nix_vt_red
        export nix_vt_grn
        export nix_vt_blu
      '';
    };
    # after the plain "splash": plymouth checks for it with strstr() and gives
    # up at the first hit, so a "plymouth.splash=" before it means no splash
    # at all (boot messages as text instead)
    boot.kernelParams = lib.mkAfter (
      if grub then
        [
          "plymouth.splash=nix-\${nix_theme}"
          "vt.default_red=\${nix_vt_red}"
          "vt.default_grn=\${nix_vt_grn}"
          "vt.default_blu=\${nix_vt_blu}"
        ]
      else
        [
          "plymouth.splash=nix-${default}"
          "vt.default_red=${vtKernel defaultVariant "r"}"
          "vt.default_grn=${vtKernel defaultVariant "g"}"
          "vt.default_blu=${vtKernel defaultVariant "b"}"
        ]
    );
    boot.initrd.supportedFilesystems.vfat = lib.mkIf (!grub) true;
    boot.initrd.systemd.storePaths = lib.mkIf (!grub) (
      [
        initrdTheme
        vtrgbs
      ]
      ++ lib.attrValues initrdBins
      ++ lib.optional config.boot.plymouth.enable plymouthStart
    );
    boot.initrd.systemd.services = lib.mkIf (!grub) {
      dotnix-boot-theme = {
        description = "Pick the boot theme theme-boot left on the ESP";
        wantedBy = [ "initrd.target" ];
        after = [ "systemd-udev-trigger.service" ];
        before = [
          "plymouth-start.service"
          "cryptsetup-pre.target"
        ];
        unitConfig.DefaultDependencies = false;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = initrdTheme;
        };
      };
      plymouth-start = lib.mkIf config.boot.plymouth.enable {
        wants = [ "dotnix-boot-theme.service" ];
        after = [ "dotnix-boot-theme.service" ];
        serviceConfig.ExecStart = [
          ""
          "${plymouthStart}"
        ];
      };
    };
    # Limine's menu in black and white, whatever the theme (its config is
    # signed: `theme` can't change it), the snowflake above it
    boot.loader.limine.style =
      let
        logo = pkgs.runCommandLocal "nix-snowflake-mono.svg" { } ''
          sed -e 's/fill:url(#linearGradient4328)/fill:#808080/' \
              -e 's/fill:url(#linearGradient4330)/fill:#ffffff/' \
              ${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg > $out
        '';
        gray = "808080";
        white = "ffffff";
      in
      {
        wallpapers = [
          (pkgs.runCommandLocal "limine-wallpaper.png" { } ''
            ${lib.getExe pkgs.resvg} -w 200 ${logo} logo.png
            ${lib.getExe pkgs.imagemagick} -size 1920x1080 xc:black \
              logo.png -gravity north -geometry +0+250 -composite $out
          '')
        ];
        wallpaperStyle = "stretched";
        backdrop = "000000";
        interface = {
          branding = "NixOS";
          brandingColor = white;
          helpColor = gray;
          helpColorBright = white;
        };
        graphicalTerminal = {
          # the wallpaper behind the text
          background = "ff000000";
          foreground = white;
          brightBackground = "333333";
          brightForeground = white;
          palette = lib.concatStringsSep ";" ([ "000000" ] ++ lib.replicate 6 gray ++ [ white ]);
          brightPalette = lib.concatStringsSep ";" ([ gray ] ++ lib.replicate 7 white);
        };
      };

    # NixOS puts only the default plymouth theme in the initrd; ship them all so
    # plymouth.splash=nix-<theme> finds any of them (same path fixup as NixOS)
    boot.initrd.systemd.contents."/etc/plymouth/themes".source = lib.mkForce (
      pkgs.runCommand "plymouth-initrd-themes" { } ''
        mkdir -p $out
        ${lib.concatMapStrings (v: ''
          cp -r ${plymouthTheme v}/share/plymouth/themes/nix-${v.id} $out/
        '') variants}
        chmod -R u+w $out
        for theme in $out/*/*.plymouth; do
          sed -i "s,${builtins.storeDir}/.*/share/plymouth/themes,$out," "$theme"
        done
      ''
    );

    boot.plymouth = {
      theme = "nix-${default}";
      themePackages = map plymouthTheme variants;
    };

    systemd.services.plymouth-poweroff.serviceConfig.ExecStart = [
      ""
      "${shutdownSplash}"
    ];
    systemd.services.plymouth-reboot.serviceConfig.ExecStart = [
      ""
      "${shutdownSplash}"
    ];
    systemd.services.plymouth-halt.serviceConfig.ExecStart = [
      ""
      "${shutdownSplash}"
    ];
    systemd.services.plymouth-kexec.serviceConfig.ExecStart = [
      ""
      "${shutdownSplash}"
    ];

    services.displayManager.sddm.settings.Theme.ThemeDir = "/var/lib/theme/sddm";
    systemd.tmpfiles.rules = [
      "d /var/lib/theme/sddm 0755 root root -"
      "L /var/lib/theme/current - - - - ${index}/${default}"
      "L /var/lib/theme/sddm/where_is_my_sddm_theme - - - - /var/lib/theme/current/sddm"
    ];

    systemd.services.theme-boot = {
      description = "Hand the user's theme to the boot screens";
      wantedBy = [ "multi-user.target" ];
      before = [ "display-manager.service" ];
      after = [
        "local-fs.target"
        "systemd-tmpfiles-setup.service"
      ];
      # browsing themes starts it many times in a row: systemd's default
      # limit (5 in 10s) would fail it and stop the path unit for the rest of
      # the session, so later changes never reached the boot screens
      unitConfig.StartLimitIntervalSec = 0;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe sync;
      };
    };
    systemd.paths.theme-boot = {
      wantedBy = [ "paths.target" ];
      unitConfig.StartLimitIntervalSec = 0;
      pathConfig.PathChanged = [
        "${stateDir}/boot"
      ];
    };

    environment.systemPackages = [ sync ];
  };
}
