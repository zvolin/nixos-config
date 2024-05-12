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
  };
}
