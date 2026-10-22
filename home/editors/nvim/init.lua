-- Plugins, language servers and formatters come from Nix (home/editors/nvim.nix)

vim.g.mapleader = " "
vim.g.maplocalleader = ","

local o = vim.opt
o.number = true
o.relativenumber = true
o.signcolumn = "yes"
o.mouse = "a"
o.clipboard = "unnamedplus"
o.undofile = true
o.ignorecase = true
o.smartcase = true
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.scrolloff = 8
o.splitright = true
o.splitbelow = true
o.updatetime = 250
o.termguicolors = true
o.list = true
o.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
o.spelllang = { "en_us", "pt_br" }

-- colors follow `theme` (dotnix home/theme), which also reloads running nvims
local theme = (vim.env.XDG_STATE_HOME or vim.fn.expand("~/.local/state")) .. "/theme/current/nvim.lua"
if not pcall(dofile, theme) then
  vim.cmd.colorscheme("habamax")
end

require("mini.icons").setup()
require("mini.statusline").setup()
require("mini.pairs").setup()
require("mini.surround").setup()
require("mini.ai").setup()
require("gitsigns").setup()
require("oil").setup()
require("which-key").setup()

local fzf = require("fzf-lua")
fzf.setup({ "default" })

-- every filetype with a grammar gets tree-sitter highlighting and folds
vim.api.nvim_create_autocmd("FileType", {
  callback = function(ev)
    if pcall(vim.treesitter.start, ev.buf) then
      vim.wo.foldmethod = "expr"
      vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
      vim.wo.foldlevel = 99
    end
  end,
})

require("blink.cmp").setup({
  keymap = { preset = "default" },
  sources = { default = { "lsp", "path", "snippets", "buffer" } },
  signature = { enabled = true },
})

-- nixd evaluates ~/dotnix: nixpkgs, NixOS and home-manager options of this host
local flake = '(builtins.getFlake "' .. vim.env.HOME .. '/dotnix")'
local host = vim.fn.hostname()
vim.lsp.config("nixd", {
  settings = {
    nixd = {
      nixpkgs = { expr = "import " .. flake .. ".inputs.nixpkgs { }" },
      options = {
        nixos = { expr = flake .. ".nixosConfigurations." .. host .. ".options" },
        home_manager = { expr = flake .. ".homeConfigurations." .. host .. ".options" },
      },
    },
  },
})
vim.lsp.config("gopls", {
  settings = { gopls = { gofumpt = true, usePlaceholders = true, staticcheck = true } },
})
vim.lsp.config("elixirls", { cmd = { "elixir-ls" } })
vim.lsp.enable({
  "nixd",
  "gopls",
  "basedpyright",
  "bashls",
  "yamlls",
  "jsonls",
  "html",
  "cssls",
  "dockerls",
  "terraformls",
  "ansiblels",
  "lua_ls",
  "rust_analyzer",
  "ts_ls",
  "elixirls",
  "elp",
  "texlab",
  "marksman",
})
vim.diagnostic.config({ virtual_text = true, severity_sort = true })

-- the same formatters as Emacs and `nix flake check`, never the servers' own
require("conform").setup({
  formatters_by_ft = {
    nix = { "nixfmt" },
    go = { "goimports", "gofumpt" },
    sh = { "shfmt" },
    bash = { "shfmt" },
    python = { "black" },
    lua = { "stylua" },
    rust = { "rustfmt" },
    javascript = { "prettier" },
    typescript = { "prettier" },
    json = { "prettier" },
    yaml = { "prettier" },
    css = { "prettier" },
    html = { "prettier" },
    markdown = { "prettier" },
  },
  formatters = { shfmt = { prepend_args = { "-i", "2" } } },
  format_on_save = { timeout_ms = 2000, lsp_format = "never" },
})

-- linters the language servers don't run
local lint = require("lint")
lint.linters_by_ft = {
  nix = { "statix" },
  dockerfile = { "hadolint" },
  go = { "golangcilint" },
}
vim.api.nvim_create_autocmd({ "FileType", "BufWritePost" }, {
  callback = function()
    lint.try_lint()
  end,
})

local map = vim.keymap.set
map("n", "<Esc>", "<Cmd>nohlsearch<CR>")
map("n", "-", "<Cmd>Oil<CR>", { desc = "Parent directory" })
map("n", "<leader><leader>", fzf.files, { desc = "Find file" })
map("n", "<leader>/", fzf.live_grep, { desc = "Search project" })
map("n", "<leader>,", fzf.buffers, { desc = "Switch buffer" })
map("n", "<leader>fr", fzf.oldfiles, { desc = "Recent files" })
map("n", "<leader>sh", fzf.helptags, { desc = "Search help" })
map("n", "<leader>cd", fzf.diagnostics_document, { desc = "Diagnostics" })
map("n", "<leader>cs", fzf.lsp_document_symbols, { desc = "Symbols" })
map("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code action" })
map("n", "<leader>cr", vim.lsp.buf.rename, { desc = "Rename" })
map("n", "<leader>cf", function()
  require("conform").format()
end, { desc = "Format" })
map("n", "gd", vim.lsp.buf.definition, { desc = "Definition" })
map("n", "gr", fzf.lsp_references, { desc = "References" })
map("n", "<leader>gb", "<Cmd>Gitsigns blame_line<CR>", { desc = "Blame line" })
map("n", "<leader>gp", "<Cmd>Gitsigns preview_hunk<CR>", { desc = "Preview hunk" })
map("n", "]h", "<Cmd>Gitsigns next_hunk<CR>")
map("n", "[h", "<Cmd>Gitsigns prev_hunk<CR>")
