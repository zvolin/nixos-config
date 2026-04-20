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
          disabled_filetypes = {
            statusline = [
              "neo-tree"
              "undotree"
            ];
            winbar = [
              "neo-tree"
              "undotree"
            ];
          };

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

        # hardtime training mode indicator
        sections.lualine_x = [
          {
            __unkeyed.__raw = ''
              function()
                if require("hardtime").is_plugin_enabled then
                  return "󰀘 Training"
                else
                  return "󰀘 <leader>th"
                end
              end
            '';
            color.__raw = ''
              function()
                if require("hardtime").is_plugin_enabled then
                  return { fg = "#a6e3a1" }  -- green when active
                else
                  return { fg = "#6c7086" }  -- dim gray when inactive
                end
              end
            '';
          }
        ];

        # add navic to the top winbar
        winbar.lualine_c = [
          {
            __unkeyed = "navic";
            color = "NavicText";
            padding = 5;
          }
        ];
        # add navic to the top winbar
        winbar.lualine_x = [
          {
            __unkeyed = "filename";
            path = 0;
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
      })
    '';
  };
}
