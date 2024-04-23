{ lib, pkgs, config, ... }:

{
  programs.nixvim = {
    enable = true;
    viAlias = true;
    vimAlias = true;

    opts = {
      # disable for theming
      background = "";
      updatetime = 100; # Faster completion

      number = true; # show line numbers
      relativenumber = true; # relative to current line

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

      swapfile = false; # don't care if I don't exit vim but shutdown system
      undofile = true; # Build-in persistent undo
    };

    globals.mapleader = " ";

    keymaps = [
      {
        key = "<leader>e";
	      action = "<CMD>Neotree toggle=true<CR>";
      }
    ];

    colorschemes.kanagawa = {
      enable = true;
      settings.theme = "dragon";
    };

    plugins.toggleterm = {
      enable = true;

      settings = {
        direction = "float";
        open_mapping = "[[<C-t>]]";
        float_opts.border = "curved";
      };
    };

    plugins.lsp = {
      enable = true;
      servers = {
        rust-analyzer = {
	        enable = true;
	        installCargo = true;
	        installRustc = true;
	      };
      };
    };

    plugins.cmp = {
      enable = true;
      autoEnableSources = true;
      settings.sources = [
        { name = "nvim-lsp"; }
        { name = "path"; }
        { name = "buffer"; }
      ];
    };

    plugins.which-key = {
      enable = true;

      window.border = "rounded";
      plugins.presets = {
        g = true;
        motions = true;
        nav = true;
        operators = true;
        textObjects = true;
        windows = true;
        z = true;
      };
    };

    plugins = {
      neo-tree.enable = true;
      telescope.enable = true;
      treesitter.enable = true;
    };
  };
}
