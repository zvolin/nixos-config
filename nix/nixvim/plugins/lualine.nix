{ pkgs, ... }:

{
  programs.nixvim = {
    plugins.lualine = {
      enable = true;

      # have single statusline instead per-window
      globalstatus = true;
      # exclude side panels
      disabledFiletypes.statusline = [
        "neo-tree"
        "undotree"
      ];

      componentSeparators = {
        left = "";
        right = "";
      };
      sectionSeparators = {
        left = "";
        right = "";
      };

      # show relative path to the file
      sections.lualine_c = [
        {
          name = "filename";
          extraConfig = {
            path = 1;
          };
        }
      ];

      # add navic to the top winbar
      winbar.lualine_c = [
        {
          name = "navic";
          # always set hl group to have uniform line color, even if navic has no output
          # offset the output by the width of number column
          fmt = ''function(text) return "%#NavicText#     " .. text end'';
        }
      ];
      inactiveWinbar.lualine_c = [
        {
          name = "navic";
          fmt = ''function(text) return "%#NavicText#" end'';
        }
      ];
    };

    extraPlugins = with pkgs.vimPlugins; [ nvim-navic ];

    extraConfigLua = ''
      require("nvim-navic").setup({
        highlight = true,
        -- handled by lsp-zero
        -- lsp = {
        --   auto_attach = true,
        -- }
      })
    '';
  };
}
