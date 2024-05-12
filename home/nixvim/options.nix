{ lib, pkgs, config, ... }:

{
  programs.nixvim.opts = {
    updatetime = 100; # Faster completion

    number = true; # show line numbers
    relativenumber = true; # relative to current line

    wrap = false;
    scrolloff = 5;
    sidescrolloff = 10;

    # use only spaces
    expandtab = true;
    autoindent = true;
    smartindent = true;
    shiftwidth = 2;
    tabstop = 2;

    # system clipboard
    clipboard = "unnamedplus";

    # searching
    ignorecase = true;
    incsearch = true;
    smartcase = true;

    # splits
    splitright = true;
    splitbelow = true;

    swapfile = false; # don't care if I don't exit vim but shutdown system
    undofile = true; # Build-in persistent undo
  };
}
