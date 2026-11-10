# what nixos-facter found here (facter.json; serial numbers left out)
{ dotlib, ... }:
{
  imports = [ (dotlib.facter ./facter.json) ];
}
