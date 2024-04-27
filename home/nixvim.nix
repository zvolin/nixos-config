{ lib, pkgs, config, ... }:

{
  programs.nixvim = {
    enable = true;
    viAlias = true;
    vimAlias = true;

    opts = {
      background = ""; # disable for theming
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
    };

    plugins.cmp = {
      enable = true;
      autoEnableSources = true;
      settings = {
        snippet.expand = "function(args) require('luasnip').lsp_expand(args.body) end";
        sources = [
          { name = "path"; }
          { name = "nvim_lsp"; }
          { name = "luasnip"; }
          {
            name = "buffer";
            # Words from other open buffers can also be suggested
            option.get_bufnrs.__raw = "vim.api.nvim_list_bufs";
          }
        ];
        mapping = {
          "<Tab>" = "cmp.mapping(cmp.mapping.select_next_item(), { 'i', 's' })";
          "<S-Tab>" = "cmp.mapping(cmp.mapping.select_prev_item(), { 'i', 's' })";
        };
        preselect = "cmp.PreselectMode.None";
      };
    };

    plugins.neo-tree = {
      enable = true;

      window = {
        width = 35;
        height = 35;
      };

      popupBorderStyle = "rounded";

      # auto resize windows on tree open and close
      eventHandlers = {
        neo_tree_window_after_open = ''
          function(args) vim.cmd('wincmd =') end
        '';
        neo_tree_window_after_close = ''
          function(args) vim.cmd('wincmd =') end
        '';
      };
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
      luasnip.enable = true;
      telescope.enable = true;
      treesitter.enable = true;
      rustaceanvim.enable = true;
    };

    extraPlugins = with pkgs.vimPlugins; [
      nvim-window-picker
    ];

    extraConfigLua = ''
      require 'window-picker'.setup({
        -- switch selection chars to dvorak home row
        selection_chars = 'uhetonas';
      })
    '';
  };
}
