{ ... }:

{
  programs.nixvim = {
    globals.mapleader = " ";

    plugins.which-key.registrations = {
      "<leader>b" = "Buffers";
      "<leader>f" = "Find";
      "<leader>w" = "Windows";
    };

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
      # Windows
      {
        key = "<leader>bC";
        action = "<cmd>BufferLineCloseOthers<cr>";
        options.desc = "Close all other buffers";
      }
      {
        key = "<leader>wv";
        action = "<cmd>vsplit<cr>";
        options.desc = "Vertical split";
      }
      {
        key = "<leader>ws";
        action = "<cmd>split<cr>";
        options.desc = "Horizontal split";
      }
      {
        key = "<leader>ww";
        action = "<cmd>wincmd p<cr>";
        options.desc = "Focus last window";
      }
      {
        key = "<leader>wh";
        action = "<cmd>wincmd h<cr>";
        options.desc = "Focus left";
      }
      {
        key = "<leader>wj";
        action = "<cmd>wincmd j<cr>";
        options.desc = "Focus down";
      }
      {
        key = "<leader>wk";
        action = "<cmd>wincmd k<cr>";
        options.desc = "Focus up";
      }
      {
        key = "<leader>wl";
        action = "<cmd>wincmd l<cr>";
        options.desc = "Focus right";
      }
      {
        key = "<leader>wH";
        action = "<cmd>wincmd H<cr>";
        options.desc = "Move window left-most";
      }
      {
        key = "<leader>wJ";
        action = "<cmd>wincmd J<cr>";
        options.desc = "Move window down-most";
      }
      {
        key = "<leader>wK";
        action = "<cmd>wincmd K<cr>";
        options.desc = "Move window up-most";
      }
      {
        key = "<leader>wL";
        action = "<cmd>wincmd L<cr>";
        options.desc = "Move window right-most";
      }
      {
        key = "<leader>wt";
        action = "<cmd>wincmd T<cr>";
        options.desc = "Move window to a new tab";
      }
      {
        key = "<leader>wo";
        action = "<cmd>only<cr>";
        options.desc = "Make current window the only one";
      }
      {
        key = "<leader>wd";
        action = "<cmd>hide<cr>";
        options.desc = "Close the window unless it's the only one";
      }
      {
        key = "<leader>wr";
        action = "<cmd>wincmd r<cr>";
        options.desc = "Rotate windows";
      }
      {
        key = "<leader>wm";
        action = "<cmd>wincmd | <bar> wincmd _<cr>";
        options.desc = "Maximize current window";
      }
      {
        key = "<leader>wR";
        action = "<cmd>wincmd =<cr>";
        options.desc = "Reset windows to equal sizes";
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
  };
}
