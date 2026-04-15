{
  config,
  lib,
  pkgs,
  bwt,
  ...
}:
let
  instanceName = config.networking.hostName;
  bwtPkg = pkgs.rustPlatform.buildRustPackage {
    pname = "bwt";
    version = "0.2.4";
    src = bwt;
    cargoHash = "sha256-ZtYZh0HNYGMCslee3QDywONRu5KZD5rnwnLvgOPevF4=";
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ pkgs.openssl ];
    doCheck = false;
  };
in
{
  # Packages
  environment.systemPackages = with pkgs; [
    # wallets
    status-im
    foundry
    liana
    (pkgs.symlinkJoin {
      name = "electrum-wayland";
      paths = [ pkgs.electrum ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/electrum \
          --set QT_QPA_PLATFORM wayland
      '';
    })
  ];

  fileSystems."/var/lib/bitcoind" = {
    device = "/var/lib/nodatacow/bitcoind";
    fsType = "none";
    options = [ "bind" ];
  };

  # BTC Node (Pruned)
  services.bitcoind."${instanceName}" = {
    enable = true;
    # Keep the last 100GB blocks
    prune = 100000;
    extraConfig = ''
      server=1
      include=/var/lib/bitcoin/rpc.env
    '';
  };

  # BWT - Bitcoin Wallet Tracker
  systemd.services.bwt = {
    description = "Bitcoin Wallet Tracker";
    after = [ "bitcoind-${instanceName}.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      EnvironmentFile = "/var/lib/bitcoin/rpc.env";
      ExecStart = "${bwtPkg}/bin/bwt --bitcoind-url http://\${RPC_USER}:\${RPC_PASS}@127.0.0.1:8332 --xpub \${ZPUB} --electrum-addr 127.0.0.1:50001";
      Restart = "always";
      User = "bitcoin";
    };
  };
}
