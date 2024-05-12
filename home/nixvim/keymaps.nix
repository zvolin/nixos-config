{ lib, pkgs, config, ... }:

{
  programs.nixvim = {
    globals.mapleader = " ";

    keymaps = [
      {
        key = "<leader>e";
        action = "<CMD>Neotree toggle=true<CR>";
      }
    ];

    # telescope
    plugins.telescope.keymaps = {
      "<C-p>" = {
        action = "git_files";
        options = {
          desc = "Telescope Git Files";
        };
      };
      "<leader>ff" = "find_files";
      "<leader>fg" = "live_grep";
    };
  };
}
