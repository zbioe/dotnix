{ config, lib, pkgs, ... }:

let
  goRoot = "${pkgs.go.out}/share/go";
  goPath = "${config.home.homeDirectory}/go";
  goBin = "${goPath}/bin";
in {
  home.sessionVariables = {
    GOROOT = [ goRoot ];
    GOPATH = [ goPath ];
    GOBIN = [ goBin ];
  };
  home.sessionPath = [ goBin ];
  home.packages = with pkgs; [
    # emacs required packages
    gore
    gocode
    goimports
    gotests
    gomodifytags
  ];
  programs.go = {
    enable = true;
    package = pkgs.go;
    goBin = goBin;
    goPath = goPath;
    packages = {
      "github.com/motemen/gore/cmd/gore" =
        builtins.fetchGit "https://github.com/motemen/gore";

      "github.com/mdempsky/gocode" =
        builtins.fetchGit "https://go.googlesource.com/tools";

      "golang.org/x/tools/cmd/godoc" =
        builtins.fetchGit "https://go.googlesource.com/tools";

      "golang.org/x/tools/cmd/goimports" =
        builtins.fetchGit "https://go.googlesource.com/tools";

      "golang.org/x/tools/cmd/gorename" =
        builtins.fetchGit "https://go.googlesource.com/tools";

      "golang.org/x/tools/cmd/guru" =
        builtins.fetchGit "https://go.googlesource.com/tools";

      "github.com/cweill/gotests/..." =
        builtins.fetchGit "https://github.com/cweill/gotests";

      "github.com/fatih/gomodifytags" =
        builtins.fetchGit "https://github.com/fatih/gomodifytags";
    };
  };
}
