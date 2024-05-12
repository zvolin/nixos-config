{ lib, pkgs, config, ... }:

{
  programs.nixvim.plugins.nvim-colorizer = {
    enable = true;
    userDefaultOptions = {
      css = true;
    };
  };
}
