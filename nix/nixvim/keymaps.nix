{ lib, ... }:

let
  noremap = mode: key: desc: action: {
    inherit key action;
    mode = lib.mkIf (mode != "") (lib.stringToCharacters mode);
    options.desc = desc;
  };
in
{
  programs.nixvim = {
    globals.mapleader = " ";

    plugins.which-key.settings.spec = [
      {
        __unkeyed = "<leader>b";
        group = "+buffers";
      }
      {
        __unkeyed = "<leader>f";
        group = "+find";
      }
      {
        __unkeyed = "<leader>g";
        group = "+git";
      }
      {
        __unkeyed = "<leader>gf";
        group = "+find";
      }
      {
        __unkeyed = "<leader>gfc";
        group = "+commit";
      }
      {
        __unkeyed = "<leader>w";
        group = "+windows";
      }
      {
        __unkeyed = "<leader>l";
        group = "+lsp";
      }
    ];

    keymaps = [
      # General
      (noremap "ti" "hk" "Exit insert mode" "<cmd>:stopinsert<cr>")
      # Side panels
      (noremap "" "<leader>e" "Toggle neotree" "<cmd>Neotree toggle=true<cr>")
      (noremap "" "<leader>e" "Toggle neotree" "<cmd>Neotree toggle=true<cr>")
      (noremap "" "<leader>u" "Toggle undotree" "<cmd>UndotreeToggle <bar> lua reset_undotree_size()<cr>")
      # Buffers
      (noremap "" "<s-h>" "Cycle previous buffer" "<cmd>BufferLineCyclePrev<cr>")
      (noremap "" "<s-l>" "Cycle next buffer" "<cmd>BufferLineCycleNext<cr>")
      (noremap "" "<leader>c" "Delete current buffer" "<cmd>Bdelete<cr>")
      (noremap "" "<leader>bp" "Pick a buffer" "<cmd>BufferLinePick<cr>")
      (noremap "" "<leader>bc" "Pick a buffer to close" "<cmd>BufferLinePickClose<cr>")
      (noremap "" "<leader>bC" "Close all other buffers" "<cmd>BufferLineCloseOthers<cr>")
      # Windows
      (noremap "" "<leader>wv" "Split" "<cmd>vsplit<cr>")
      (noremap "" "<leader>ww" "Focus last window" "<cmd>wincmd p<cr>")
      (noremap "" "<leader>wh" "Focus left" "<cmd>wincmd h<cr>")
      (noremap "" "<leader>wj" "Focus down" "<cmd>wincmd j<cr>")
      (noremap "" "<leader>wk" "Focus up" "<cmd>wincmd k<cr>")
      (noremap "" "<leader>wl" "Focus right" "<cmd>wincmd l<cr>")
      (noremap "" "<leader>wH" "Move window left-most" "<cmd>wincmd H<cr>")
      (noremap "" "<leader>wJ" "Move window down-most" "<cmd>wincmd J<cr>")
      (noremap "" "<leader>wK" "Move window up-most" "<cmd>wincmd K<cr>")
      (noremap "" "<leader>wL" "Move window right-most" "<cmd>wincmd L<cr>")
      (noremap "" "<leader>wo" "Close all other windows" "<cmd>only<cr>")
      (noremap "" "<leader>wd" "Hide the window" "<cmd>hide<cr>")
      (noremap "" "<leader>wr" "Rotate windows" "<cmd>wincmd r<cr>")
      (noremap "" "<leader>wm" "Maximize current window" "<cmd>wincmd | <bar> wincmd _<cr>")
      (noremap "" "<leader>wR" "Reset windows sizes" "<cmd>wincmd =<cr>")
      # Find
      (noremap "" "<leader>ff" "Find file" "<cmd>Telescope find_files<cr>")
      (noremap "" "<leader>fg" "Live grep" "<cmd>Telescope live_grep<cr>")
      (noremap "" "<leader>fG" "Grep under cursor" "<cmd>Telescope grep_string<cr>")
      (noremap "" "<leader>fb" "Find buffer" "<cmd>Telescope buffers<cr>")
      (noremap "" "<leader>fF" "Files history" "<cmd>Telescope oldfiles<cr>")
      (noremap "" "<leader>fc" "Command history" "<cmd>Telescope command_history<cr>")
      (noremap "" "<leader>fC" "Vim commands" "<cmd>Telescope commands<cr>")
      (noremap "" "<leader>fs" "Search history" "<cmd>Telescope search_history<cr>")
      (noremap "" "<leader>fl" "Search loclist" "<cmd>Telescope loclist<cr>")
      (noremap "" "<leader>fj" "Search jumplist" "<cmd>Telescope jumplist<cr>")
      (noremap "" "<leader>fr" "Search registers" "<cmd>Telescope registers<cr>")
      (noremap "" "<leader>fp" "Find projects"
        "<cmd>lua require('telescope').extensions.projects.projects()<cr>"
      )
      (noremap "" "<leader>fn" "Search NixOs man"
        "<cmd>lua require('telescope').extensions.manix.manix()<cr>"
      )
      # Git
      # Git find
      (noremap "" "<leader>gff" "Find file" "<cmd>Telescope git_files<cr>")
      (noremap "" "<leader>gfcc" "commit in repo" "<cmd>Telescope git_commits<cr>")
      (noremap "" "<leader>gfcb" "commit in buffer" "<cmd>Telescope git_bcommits<cr>")
      (noremap "" "<leader>gfcv" "commit in selection" "<cmd>Telescope git_bcommits_range<cr>")
      (noremap "" "<leader>gfb" "Find branch" "<cmd>Telescope git_branches<cr>")
      (noremap "" "<leader>gfs" "Apply stash" "<cmd>Telescope git_stash<cr>")
      # Lsp
      (noremap "" "<leader>la" "Code actions" "<cmd>lua vim.lsp.buf.code_action()<cr>")
      (noremap "" "<leader>lr" "References" "<cmd>Telescope lsp_references<cr>")
      (noremap "" "<leader>ls" "Buffer symbols" "<cmd>Telescope lsp_document_symbols<cr>")
      (noremap "" "<leader>lS" "Workspace symbols" "<cmd>Telescope lsp_workspace_symbols<cr>")
      (noremap "" "<leader>ld" "Definitions" "<cmd>Telescope lsp_definitions<cr>")
      (noremap "" "<leader>li" "Implementations" "<cmd>Telescope lsp_implementations<cr>")
      (noremap "" "<leader>lc" "Buffer diagnostics" "<cmd>Telescope diagnostics bufnr=0<cr>")
      (noremap "" "<leader>lC" "Workspace diagnostics" "<cmd>Telescope diagnostics<cr>")
      (noremap "" "<leader>lh" "Toggle inlay hints"
        "<cmd>lua vim.lsp.inlay_hint.enable(vim.lsp.inlay_hint.is_enabled(), { 0 })<cr>"
      )
      # Terminal
      ## remap shift backspace and enter, for some reason when zsh in vi mode is used
      ## from toggleterm from kitty, it wipes current line and switches to normal mode in zsh
      (noremap "t" "<s-bs>" "Fix shift-backspace wiping cmd" "<bs>")
      (noremap "t" "<s-cr>" "Fix shift-enter wiping cmd" "<cr>")
    ];
  };
}
