{ ... }:

{
  programs.nixvim.plugins.lualine = {
    enable = true;

    disabledFiletypes.statusline = [ "neo-tree" "undotree" ];

    componentSeparators = {
      left = "";
      right = "";
    };
    sectionSeparators = {
      left = "";
      right = "";
    };
  };
}
