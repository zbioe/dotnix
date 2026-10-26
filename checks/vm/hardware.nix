# dotnix-hardware, what dotnix-install writes as hosts/<host>/hardware.nix:
# a desktop, then the same machine with a battery (a laptop)
{ pkgs, ... }:
{
  name = "dotnix-hardware";

  node.specialArgs.username = "zbioe";
  nodes.machine = {
    imports = [ ../../iso/tools.nix ];
    documentation.enable = false;
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    def modules():
        # (valid Nix too)
        machine.succeed("dotnix-hardware /dev/vda > /tmp/hardware.nix")
        machine.succeed("${pkgs.nix}/bin/nix-instantiate --parse /tmp/hardware.nix >/dev/null")
        return machine.succeed("cat /tmp/hardware.nix")

    with subtest("no battery: a desktop"):
        out = modules()
        assert "nixosModules.common-pc\n" in out, out
        assert "common-pc-laptop" not in out, out

    with subtest("a battery: a laptop"):
        machine.succeed("mount -t tmpfs none /sys/class/power_supply && mkdir /sys/class/power_supply/BAT0")
        out = modules()
        assert "nixosModules.common-pc-laptop\n" in out, out
        assert "nixosModules.common-pc\n" not in out, out
  '';
}
