{
  config,
  lib,
  pkgs,
  ...
}:
let
  emacs-wl =
    (pkgs.emacs-pgtk.override {
      withNativeCompilation = true;
      withTreeSitter = true;
      withXwidgets = true;
    }).overrideAttrs
      (old: {
        meta = (old.meta or { }) // {
          broken = false;
        };
        postPatch = (old.postPatch or "") + ''
          sed -i 's/WEBKIT_BROKEN=2.41.92/WEBKIT_BROKEN=9.99.99/g' configure.ac configure || true
        '';
      });
in
{
  options.dotnix.editors.emacs.enable = lib.mkEnableOption "Emacs (daemon and client)";

  config = lib.mkIf config.dotnix.editors.emacs.enable {
    programs.emacs = {
      enable = true;
      package = emacs-wl;
    };
    services.emacs = {
      enable = true;
      package = emacs-wl;
      client.enable = true;
    };
  };
}
