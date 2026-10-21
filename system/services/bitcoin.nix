# A pruned Bitcoin node, and BWT (an Electrum server for your own wallets) on top
{
  config,
  lib,
  pkgs,
  bwt,
  ...
}:
let
  cfg = config.dotnix.services.bitcoin;
  # RPC_USER, RPC_PASS (and ZPUB for bwt): from secrets/, or by hand in /var/lib/bitcoin
  rpcEnv =
    if config.dotnix.core.secrets.enable then
      config.sops.secrets.bitcoin-rpc-env.path
    else
      "/var/lib/bitcoin/rpc.env";
  instance = config.networking.hostName;
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
  options.dotnix.services.bitcoin = {
    enable = lib.mkEnableOption "a pruned Bitcoin node";
    bwt.enable = lib.mkEnableOption "BWT on the node";
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.enable && config.dotnix.core.secrets.enable) {
      sops.secrets.bitcoin-rpc-env.owner = config.services.bitcoind.${instance}.user;
    })
    (lib.mkIf cfg.enable {
      environment.persistence."/persist".directories = [ "/var/lib/bitcoin" ];
      fileSystems."/var/lib/bitcoind" = {
        device = "/var/lib/nodatacow/bitcoind";
        fsType = "none";
        options = [ "bind" ];
      };
      services.bitcoind.${instance} = {
        enable = true;
        prune = 100000; # the last 100GB of blocks
        extraConfig = ''
          server=1
          include=${rpcEnv}
        '';
      };
    })
    (lib.mkIf cfg.bwt.enable {
      systemd.services.bwt = {
        description = "Bitcoin Wallet Tracker";
        after = [ "bitcoind-${instance}.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          EnvironmentFile = rpcEnv;
          ExecStart = "${bwtPkg}/bin/bwt --bitcoind-url http://\${RPC_USER}:\${RPC_PASS}@127.0.0.1:8332 --xpub \${ZPUB} --electrum-addr 127.0.0.1:50001";
          Restart = "always";
          User = "bitcoin";
        };
      };
    })
  ];
}
