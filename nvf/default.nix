{ pkgs, ... }:
let
  theme = "gruvbox";
in
{
  imports = [
    ./keymaps.nix
  ];

  vim = {
    viAlias = false;
    vimAlias = false;

    theme = {
      enable = true;
      name = theme;
      style = "dark";
      transparent = true;
    };

    assistant.copilot = {
      enable = false;
      cmp.enable = false;
    };

    spellcheck = {
      enable = true;
    };

    options = {
      smartindent = true;
      mouse = "a";
      magic = true;
      shiftround = true;
      expandtab = true;
      tabstop = 4;
      shiftwidth = 2;
    };

    lsp = {
      enable = true;
      formatOnSave = true;
      lspkind.enable = false;
      lightbulb.enable = true;
      lspsaga.enable = false;
      trouble.enable = true;
      lspSignature.enable = true;
    };

    debugger = {
      nvim-dap = {
        enable = true;
        ui.enable = true;
      };
    };

    languages = {
      enableFormat = true;
      enableTreesitter = true;
      enableExtraDiagnostics = true;
      nix = {
        enable = true;
        extraDiagnostics.enable = true;
        lsp = {
          enable = true;
          package = pkgs.nixd;
          server = "nixd";
          options = {
            nixpkgs.expr = "import <nixpkgs> {}";
            nixos.expr = "(import <nixpkgs/nixos> {}).config";
            home.expr = "(import <home-manager> {}).config";
            formatting.command = [ "nixfmt" ];
          };
        };
        treesitter.enable = true;
        format = {
          enable = true;
          type = "nixfmt";
          package = pkgs.nixfmt-rfc-style;
        };
      };
      markdown.enable = true;
      bash.enable = true;
      elixir.enable = true;
      html.enable = true;
      css = {
        enable = true;
        format.type = "prettierd";
      };
      tailwind.enable = true;
      ts = {
        enable = true;
        format.type = "prettierd";
      };
    };

    visuals = {
      nvim-scrollbar.enable = false;
      nvim-web-devicons.enable = true;
      nvim-cursorline.enable = true;
      cinnamon-nvim.enable = true;
      fidget-nvim.enable = true;
      highlight-undo.enable = true;
      indent-blankline.enable = true;
    };

    statusline = {
      lualine = {
        enable = true;
        inherit theme;
      };
    };
    autopairs.nvim-autopairs.enable = true;
    autocomplete.nvim-cmp.enable = true;
    snippets.luasnip.enable = true;
    telescope.enable = true;
    filetree = {
      neo-tree = {
        enable = true;
      };
    };

    tabline = {
      nvimBufferline.enable = true;
    };

    treesitter.context.enable = false;

    binds = {
      whichKey.enable = true;
      cheatsheet.enable = true;
    };

    git = {
      enable = true;
      gitsigns.enable = true;
      gitsigns.codeActions.enable = false; # throws an annoying debug message
    };

    minimap = {
      minimap-vim.enable = false;
      codewindow.enable = true; # lighter, faster, and uses lua for configuration
    };

    dashboard = {
      dashboard-nvim.enable = false;
      alpha.enable = true;
    };

    notify = {
      nvim-notify = {
        enable = true;
        setupOpts.background_colour = "#282828";
      };

    };

    projects = {
      project-nvim.enable = true;
    };

    utility = {
      vim-wakatime.enable = false;
      yanky-nvim.enable = false;
      ccc.enable = true;
      diffview-nvim.enable = true;
      icon-picker.enable = true;
      surround.enable = true;
      multicursors.enable = true;

      motion = {
        hop.enable = true;
        leap.enable = true;
        precognition.enable = true;
      };
      images = {
        image-nvim.enable = false;
      };
    };

    notes = {
      todo-comments.enable = true;
    };

    terminal = {
      toggleterm = {
        enable = true;
        lazygit.enable = true;
      };
    };

    ui = {
      borders.enable = true;
      noice.enable = true;
      colorizer.enable = true;
      modes-nvim.enable = false; # the theme looks terrible with catppuccin
      illuminate.enable = true;
      breadcrumbs = {
        enable = true;
        navbuddy.enable = true;
      };
      smartcolumn = {
        enable = true;
        setupOpts.custom_colorcolumn = {
          # this is a freeform module, it's `buftype = int;` for configuring column position
          nix = "110";
        };
      };
      fastaction.enable = true;
    };

    session = {
      nvim-session-manager.enable = false;
    };

    gestures = {
      gesture-nvim.enable = false;
    };

    comments = {
      comment-nvim.enable = true;
    };
  };
}
