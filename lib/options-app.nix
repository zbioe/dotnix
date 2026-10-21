{
  writeShellApplication,
  jq,
  gnugrep,
  util-linux,
}:
writeShellApplication {
  name = "dotnix-options";
  runtimeInputs = [
    jq
    gnugrep
    util-linux
  ];
  text = ''
    host=''${1:?usage: nix run .#options -- HOST [FILTER]}
    nix eval --json ".#nixosConfigurations.$host.config.dotnix" --apply '
      let
        show =
          v:
          if builtins.isFunction v then "<function>"
          else if builtins.isList v then map show v
          else if !builtins.isAttrs v then v
          else if v.type or "" == "derivation" then v.name
          else if v ? callPackage && v ? kernel then v.kernel.name
          else builtins.mapAttrs (_: show) v;
      in
      show' |
      jq -r 'paths((type != "object" and type != "array") or . == []) as $p | "\($p | map(tostring) | join("."))\t\(getpath($p))"' |
      grep -- "''${2:-}" | column -t -s $'\t'
  '';
}
