_: {
  vim.keymaps = [
    {
      key = "<C-z>";
      mode = [ "i" ];
      action = "<Esc>^i";
      desc = " of line";
    }
    {
      key = "<C-s>";
      mode = [ "i" ];
      action = "<End>";
      desc = "end of line";
    }
    {
      key = "<C-l>";
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
  ];
}
