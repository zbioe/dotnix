# nixpkgs' Proton Pass on the newest stable build from Proton (the
# proton-pass flake input, moved forward by flake-updates)
{
  proton-pass,
  dpkg,
  runCommand,
  src,
}:
let
  version = builtins.readFile (
    runCommand "proton-pass-version" { nativeBuildInputs = [ dpkg ]; } ''
      dpkg-deb -f ${src} Version | tr -d '\n' > $out
    ''
  );
in
proton-pass.overrideAttrs {
  inherit version src;
  unpackPhase = "dpkg-deb --fsys-tarfile $src | tar -x --no-same-permissions --no-same-owner";
}
