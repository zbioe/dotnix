{
  config,
  pkgs,
  unstable,
  home-module,
  ...
}:
let
  users = [
    "root"
    config.dotnix.core.user.name
  ];
in
{
  imports = [
    ./substituters.nix
    ./nh.nix
  ];

  nixpkgs.config.allowUnfree = true;

  nix = {
    nixPath = [
      "nixpkgs=${pkgs.path}"
      "unstable=${unstable.path}"
      "home-manager=${home-module}"
    ];
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
        "pipe-operators"
      ];
      trusted-users = users;
      allowed-users = users;
      auto-optimise-store = true;
      builders-use-substitutes = true;
    };
    extraOptions = ''
      keep-outputs = true
      keep-derivations = true
      tarball-ttl = 900
    '';
  };
}
