{
  config,
  lib,
  pkgs,
  dotlib,
  ...
}:
let
  cfg = config.dotnix.packages.base;
in
{
  options.dotnix.packages.base = dotlib.mkPackages "terminal utilities";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = dotlib.packagesOf cfg (
      with pkgs;
      [
        # files and disks
        eza # ls alternative
        fd # find alternative
        ripgrep # grep alternative
        fzf # fuzzy finder
        jq # json query
        broot # tree file manager
        lstr # tree alternative
        trashy # trash from the terminal
        gdu # disk usage
        caligula # dd with a TUI
        unzip # zip archives
        gzip # gzip archives
        gnutar # tar archives
        gnome-disk-utility # partitions, visually
        ntfs3g # NTFS support
        parted # disk partitioning
        e2fsprogs # ext2/3/4 utilities
        (grub2.override { efiSupport = true; }) # grub utilities

        # system
        btop # resource monitor
        bottom # btop alternative
        nvtopPackages.intel # Intel GPU monitor
        nvtopPackages.nvidia # NVIDIA GPU monitor
        nethogs # network use per process
        fwupd # firmware updates
        busybox # small unix utilities
        libossp_uuid # uuid generator

        # network
        wget # downloads
        dig # DNS lookup
        wireguard-tools # wireguard CLI

        # terminal
        lsix # images in the terminal (sixel)
        chafa # images in the terminal
        sc-im # spreadsheets
        ispell # spell checker

        # editors
        vim # vi improved
        neovim # vim improved
        helix # modal editor
      ]
    );
  };
}
