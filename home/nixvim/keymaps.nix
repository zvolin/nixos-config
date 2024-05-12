{ lib, pkgs, config, ... }:

{
  programs.nixvim = {
    globals.mapleader = " ";

    keymaps = [
      # toggle neotree
      {
        key = "<leader>e";
        action = "<CMD>Neotree toggle=true<CR>";
      }
      # toggle undotree
      {
        key = "<leader>u";
        action = "<CMD>UndotreeToggle<CR>";
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
