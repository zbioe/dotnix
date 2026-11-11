# sudo through pam_either (system/core/security.nix), in a real terminal:
# the fingerprint wins without typing, the password wins without waiting on
# the reader, a wrong one fails at once, ^C leaves no helper behind. The
# reader is a stand-in that "matches" once /tmp/finger appears
{ pkgs, ... }:
let
  # waits for a file under /tmp; the watch is up before the check, so the
  # file can't appear in between
  waitFor = pkgs.writeScript "wait-for" ''
    #!${pkgs.bash}/bin/bash
    coproc watch { ${pkgs.inotify-tools}/bin/inotifywait -t 60 -e create --include "/$1\$" /tmp 2>&1; }
    until read -r line <&"''${watch[0]}" && [ "$line" = "Watches established." ]; do :; done
    shift
    "$@"
    [ -e "/tmp/$1" ] && exit 0
    read -r line <&"''${watch[0]}" || true
  '';
  fakeReader = pkgs.writeScript "fake-reader" ''
    #!${pkgs.bash}/bin/bash
    ${waitFor} finger echo "Place your finger on the fingerprint reader"
    [ -e /tmp/finger ]
  '';
  expectScript =
    name: body:
    pkgs.writeText "${name}.exp" ''
      set timeout 20
      log_user 1
      spawn sudo -k true
      ${body}
      expect eof
      lassign [wait] pid spawnid os_error value
      exit $value
    '';
  finger = expectScript "finger" ''
    expect "Place your finger"
    expect "password for alice"
    exec touch /tmp/finger
  '';
  password = expectScript "password" ''
    expect "Place your finger"
    expect "password for alice"
    send "secret\r"
  '';
  wrong = expectScript "wrong" ''
    expect "password for alice"
    send "wrong\r"
    set timeout 5
    expect {
      "Sorry, try again" { send "\003" }
      timeout { puts "waited on the reader"; exit 9 }
    }
  '';
  # ^C once the test saw sudo blocked reading the password: sent before the
  # read starts, plain sudo itself misses it (its handler runs first)
  cancel = expectScript "cancel" ''
    expect "password for alice"
    exec ${waitFor} go true
    send "\003"
    set timeout 5
    expect {
      eof {}
      timeout { puts "ignored ^C"; exit 8 }
    }
  '';
in
{
  name = "dotnix-pam-either";

  nodes.machine =
    { lib, ... }:
    {
      imports = [ ../../system/core/security.nix ];
      services.fprintd.enable = true;
      dotnix.core.sudo.fingerprintOrPassword.enable = true;
      security.pam.services.sudo.rules.auth.either.args = lib.mkAfter [ "debug" ];
      # the reader's service, faked
      security.pam.services.sudo-fprint.text = lib.mkForce ''
        auth required pam_exec.so stdout ${fakeReader}
      '';
      users.users.alice = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        password = "secret";
      };
      environment.systemPackages = [ pkgs.expect ];
    };

  testScript = ''
    import time

    machine.wait_for_unit("multi-user.target")

    def run(script):
        start = time.monotonic()
        status, out = machine.execute(f"su alice -c 'expect {script}' 2>&1")
        print(out)
        return status, out, time.monotonic() - start

    with subtest("the fingerprint wins, nothing typed"):
        machine.succeed("rm -f /tmp/finger")
        status, out, took = run("${finger}")
        assert status == 0, f"sudo failed ({status})"
        assert took < 15, f"the finger didn't end the prompt: {took:.1f}s"
        assert out.index("Place your finger") < out.index("password for alice"), "hint after the prompt"

    with subtest("the password wins without waiting on the reader"):
        machine.succeed("rm -f /tmp/finger")
        status, out, took = run("${password}")
        assert status == 0, f"sudo failed ({status})"
        assert took < 15, f"waited on the reader: {took:.1f}s"

    with subtest("a wrong password fails at once"):
        machine.succeed("rm -f /tmp/finger")
        status, out, took = run("${wrong}")
        assert status != 9, "the wrong password waited on the reader"
        assert "Sorry, try again" in out

    with subtest("^C cancels and leaves no helper"):
        for attempt in range(10):
            machine.succeed("rm -f /tmp/finger /tmp/go /tmp/status")
            machine.execute("su alice -c 'expect ${cancel}; echo $? > /tmp/status' >/dev/null 2>&1 &")
            # sudo's own thread blocked reading the terminal
            machine.wait_until_succeeds("grep -q n_tty_read /proc/$(pgrep -xo sudo)/stack", timeout=30)
            machine.succeed("touch /tmp/go")
            machine.wait_until_succeeds("test -s /tmp/status", timeout=30)
            status = int(machine.succeed("cat /tmp/status"))
            assert status != 8, f"attempt {attempt}: ^C was ignored"
            assert status != 0, f"attempt {attempt}: sudo ran after ^C"
        machine.wait_until_fails("pgrep -x pam-either-help")
  '';
}
