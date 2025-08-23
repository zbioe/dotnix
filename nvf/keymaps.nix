_: {
  vim.keymaps = [
    {
      key = "<C-a>";
      mode = [ "i" ];
      action = "<Esc>^i";
      desc = "start of line";
    }
    {
      key = "<C-e>";
      mode = [ "i" ];
      action = "<End>";
      desc = "end of line";
    }
    {
      key = "<C-f>";
      mode = [ "i" ];
      action = "<Right>";
      desc = "to right";
    }
    {
      key = "<C-b>";
      mode = [ "i" ];
      action = "<Left>";
      desc = "to left";
    }
    {
      key = "<C-h>";
      mode = [ "n" ];
      action = ":tabprevious<CR>";
      desc = "previus tab";
    }
    {
      key = "<C-l>";
      mode = [ "n" ];
      action = ":tabnext<CR>";
      desc = "next tab";
    }
  ];
}
