# GDM's login screen themed live, no gnome-shell rebuild: the greeter's
# shell runs a session mode of ours (parent gdm) whose stylesheet isn't in
# its compiled resource, so gnome-shell finds it in the data dirs, a link to
# /var/lib/dotnix-gdm; its wallpaper is a file there too. Changing them and
# showing the login screen again changes what's on screen, read off it.
{ pkgs, ... }:
let
  css = "/var/lib/dotnix-gdm/gnome-shell.css";
  wallpaper = "/var/lib/dotnix-gdm/wallpaper.png";
  png =
    color:
    pkgs.runCommand "wallpaper.png" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
      magick -size 1024x768 xc:'${color}' png24:$out
    '';
  mode = pkgs.runCommand "dotnix-gdm-mode" { } ''
    mkdir -p $out/share/gnome-shell/modes $out/share/gnome-shell/theme
    echo '{ "parentMode": "gdm", "stylesheetName": "dotnix-gdm.css" }' \
      > $out/share/gnome-shell/modes/dotnix-gdm.json
    # gnome-shell tries the -dark/-light variant first, then the name
    for v in "" -dark -light; do
      ln -s ${css} $out/share/gnome-shell/theme/dotnix-gdm$v.css
    done
  '';
  # the login dialog fills the screen: painting it shows the stylesheet
  # loaded; without it, the wallpaper (the greeter draws none of its own:
  # only what the stylesheet puts behind the dialog)
  stylesheet = dialog: ''
    @import url("resource:///org/gnome/shell/theme/gnome-shell-dark.css");
    #lockDialogGroup {
      background-image: url("file://${wallpaper}");
      background-size: cover;
      background-position: center;
    }
    ${if dialog == null then "" else ".login-dialog { background-color: ${dialog}; }"}
  '';
in
{
  name = "dotnix-gdm-theme";

  nodes.machine = {
    imports = [ "${pkgs.path}/nixos/tests/common/user-account.nix" ];
    virtualisation.memorySize = 2048;
    services.displayManager.gdm.enable = true;
    # a session to pick at the login screen
    programs.sway.enable = true;
    # the greeter only looks in these (and gnome-shell's own) data dirs
    services.displayManager.gdm.extraPackages = [ mode ];
    systemd.tmpfiles.rules = [ "d /var/lib/dotnix-gdm 0755 root root -" ];
    environment.etc."dotnix-gdm-start.css".text = stylesheet "#a03050";
    environment.etc."dotnix-gdm-next.css".text = stylesheet null;
    environment.etc."dotnix-gdm-start.png".source = png "#204080";
    environment.etc."dotnix-gdm-next.png".source = png "#307050";
    systemd.services.display-manager.preStart = ''
      [ -e ${css} ] || cp /etc/dotnix-gdm-start.css ${css}
      [ -e ${wallpaper} ] || cp /etc/dotnix-gdm-start.png ${wallpaper}
    '';
    # the greeter's shell (org.gnome.Shell@gdm, run by GDM's dynamic greeter user) in our mode
    systemd.user.services."org.gnome.Shell@gdm".serviceConfig.ExecStart = [
      ""
      "${pkgs.gnome-shell}/bin/gnome-shell --mode=dotnix-gdm"
    ];
  };

  testScript = ''
    from collections import Counter

    def background():
        # the screen's most common color, from a raw screendump (P6)
        shot = machine.state_dir / "screen.ppm"
        machine.send_monitor_command(f"screendump {shot}")
        data = shot.read_bytes()
        magic, width, height, depth, pixels = data.split(maxsplit=4)
        assert magic == b"P6" and depth == b"255"
        rgb = Counter(bytes(pixels[i:i + 3]) for i in range(0, len(pixels) - 2, 3 * 97))
        return "#" + rgb.most_common(1)[0][0].hex()

    def shows(color):
        def check(last):
            seen = background()
            assert seen == color or not last, f"background {seen}, not {color}"
            return seen == color
        retry(check, timeout_seconds=120)
        machine.screenshot("gdm-" + color[1:])

    # the greeter's shell, and the mode it was started in (its process is
    # the wrapper's, named .gnome-shell-wr)
    def shell_args():
        machine.wait_until_succeeds("pgrep -x .gnome-shell-wr", timeout=180)
        return machine.succeed("tr '\\0' ' ' < /proc/$(pgrep -x .gnome-shell-wr | head -1)/cmdline")

    machine.wait_for_unit("display-manager.service")
    args = shell_args()
    print(args)
    assert "--mode=dotnix-gdm" in args, args
    shows("#a03050")

    with subtest("a new stylesheet and wallpaper show on the next boot's login screen"):
        machine.succeed("cp /etc/dotnix-gdm-next.css ${css}")
        machine.succeed("cp /etc/dotnix-gdm-next.png ${wallpaper}")
        machine.shutdown()
        machine.start()
        machine.wait_for_unit("display-manager.service")
        assert "--mode=dotnix-gdm" in shell_args()
        shows("#307050")

    with subtest("no stylesheet errors"):
        print(machine.succeed("journalctl -b -u display-manager --no-pager | tail -20"))
        machine.fail("journalctl -b --no-pager | grep -i 'dotnix-gdm.*\\(error\\|invalid\\)'")
  '';
}
