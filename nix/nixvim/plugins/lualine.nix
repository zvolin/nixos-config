{ pkgs, lib, ... }:

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

    extraConfigLua =
      let
        # set the hl groups for navic items. maybe upstream to 'base16-nvim'?
        hl_group_map = {
          NavicIconsFile = "Directory";
          NavicIconsModule = "@module";
          NavicIconsNamespace = "@module";
          NavicIconsPackage = "@module";
          NavicIconsClass = "Type";
          NavicIconsMethod = "@function.method";
          NavicIconsProperty = "@property";
          NavicIconsField = "@variable.member";
          NavicIconsConstructor = "@constructor";
          NavicIconsEnum = "Type";
          NavicIconsInterface = "Type";
          NavicIconsFunction = "Function";
          NavicIconsVariable = "@variable";
          NavicIconsConstant = "Constant";
          NavicIconsString = "String";
          NavicIconsNumber = "Number";
          NavicIconsBoolean = "Boolean";
          NavicIconsArray = "Type";
          NavicIconsObject = "Type";
          NavicIconsKey = "Identifier";
          NavicIconsNull = "Type";
          NavicIconsEnumMember = "Constant";
          NavicIconsStruct = "Structure";
          NavicIconsEvent = "Structure";
          NavicIconsOperator = "Operator";
          NavicIconsTypeParameter = "Type";
          NavicText = "Comment";
          NavicSeparator = "Comment";
        };
      in
      ''
        require("nvim-navic").setup({
          highlight = true,
          -- handled by lsp-zero
          -- lsp = {
          --   auto_attach = true,
          -- }
        })
      ''
      + lib.concatStringsSep "\n" (
        lib.attrsets.mapAttrsToList (
          hl_group: source_group: ''vim.api.nvim_set_hl(0, "${hl_group}", { link = "${source_group}" })''
        ) hl_group_map
      );
  };
}
