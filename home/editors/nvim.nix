# Neovim kept simple: a handful of plugins from nixpkgs and nvim/init.lua;
# the language servers are the system's (system/packages/dev.nix and nix.nix)
{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.dotnix.editors.nvim.enable = lib.mkEnableOption "Neovim";

  config = lib.mkIf config.dotnix.editors.nvim.enable {
    home.packages = [ pkgs.stylua ]; # lua formatter, Emacs's too
    programs.neovim = {
      enable = true;
      viAlias = true;
      vimAlias = true;
      initLua = builtins.readFile ./nvim/init.lua;
      plugins = with pkgs.vimPlugins; [
        nvim-treesitter.withAllGrammars # parsers for every language
        mini-nvim # base16 colors, statusline, pairs, surround, text objects
        blink-cmp # completion
        nvim-lspconfig # language server defaults
        conform-nvim # format on save
        nvim-lint # extra linters
        fzf-lua # fuzzy finder
        gitsigns-nvim # git in the gutter
        which-key-nvim # key hints
        oil-nvim # directories as buffers
      ];
      extraPackages = with pkgs; [
        fzf # fzf-lua
        rustfmt # rust formatter
      ];
    };
  };
}
