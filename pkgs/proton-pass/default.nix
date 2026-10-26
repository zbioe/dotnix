# nixpkgs' Proton Pass on Proton's own build (the proton-pass flake input,
# moved to the newest stable one by flake-updates)
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
