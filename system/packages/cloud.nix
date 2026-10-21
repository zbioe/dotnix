{
  config,
  lib,
  pkgs,
  unstable,
  dotlib,
  ...
}:
let
  cfg = config.dotnix.packages.cloud;
  terraform = unstable.terraform.withPlugins (p: [
    p.dmacvicar_libvirt
    p.hashicorp_azurerm
    p.hashicorp_local
    p.vancluever_acme
    p.hashicorp_aws
    p.nbering_ansible
  ]);
in
{
  options.dotnix.packages.cloud = dotlib.mkPackages "cloud and infrastructure tools";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = dotlib.packagesOf cfg (
      with pkgs;
      [
        terraform # infrastructure as code, with the plugins used
        ansible # configuration management
        nomad # nomad cli
        certbot-full # TLS certificates
        sshuttle # VPN over ssh

        # clouds
        awscli2 # AWS
        azure-cli # Azure
        google-cloud-sdk # Google Cloud
        oci-cli # Oracle Cloud

        # kubernetes
        kubectl # kubernetes cli
        kubelogin # kubectl auth
        kubernetes-helm # charts
        kind # local clusters
        cilium-cli # cilium
      ]
    );
  };
}
