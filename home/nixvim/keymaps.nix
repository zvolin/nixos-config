{ ... }:

{
  programs.nixvim = {
    globals.mapleader = " ";

    keymaps = [
      # Side panels
      {
        key = "<leader>e";
        action = "<cmd>Neotree toggle=true<cr>";
        options.desc = "Toggle neotree";
      }
      {
        key = "<leader>u";
        action = "<cmd>UndotreeToggle <bar> lua reset_undotree_size()<cr>";
        options.desc = "Toggle undotree";
      }
      # Buffers
      {
        key = "<s-h>";
        action = "<cmd>BufferLineCyclePrev<cr>";
        options.desc = "Cycle previous buffer";
      }
      {
        key = "<s-l>";
        action = "<cmd>BufferLineCycleNext<cr>";
        options.desc = "Cycle next buffer";
      }
      {
        key = "<leader>c";
        action = "<cmd>Bdelete<cr>";
        options.desc = "Delete current buffer";
      }
      {
        key = "<leader>bp";
        action = "<cmd>BufferLinePick<cr>";
        options.desc = "Pick a buffer";
      }
      {
        key = "<leader>bc";
        action = "<cmd>BufferLinePickClose<cr>";
        options.desc = "Pick a buffer to close";
      }
      {
        key = "<leader>bC";
        action = "<cmd>BufferLineCloseOthers<cr>";
        options.desc = "Close all other buffers";
      }
    ];

    plugins.telescope.keymaps = {
      "<c-p>" = {
        action = "git_files";
        options.desc = "Telescope Git Files";
      };
      "<leader>ff" = {
        action = "find_files";
        options.desc = "Telescope find files";
      };
      "<leader>fg" = {
        action = "live_grep";
        options.desc = "Telescope live grep";
      };
    };

    plugins.which-key.registrations = {
      "<leader>b" = "Buffers";
      "<leader>f" = "Find";
    };
  };
}
