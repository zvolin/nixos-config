{ pkgs, ... }:

{
  programs.nixvim = {
    plugins.lualine = {
      enable = true;

      settings = {
        options = {
          # have single statusline instead per-window
          globalstatus = true;
          # exclude side panels
          disabled_filetypes = [
            "neo-tree"
            "undotree"
          ];

          component_separators = {
            left = "";
            right = "";
          };
          section_separators = {
            left = "";
            right = "";
          };
        };

        # show relative path to the file
        sections.lualine_c = [
          {
            __unkeyed = "filename";
            path = 3;
          }
        ];

        # add navic to the top winbar
        winbar.lualine_c = [
          {
            __unkeyed = "navic";
            color = "NavicText";
            padding = 5;
            fmt = "function(text) if (text == nil or text == '') then return ' ' else return text end end";
          }
        ];
        inactive_winbar.lualine_x = [
          {
            __unkeyed = "filename";
            path = 1;
            color = "NavicText";
          }
        ];
      };
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
