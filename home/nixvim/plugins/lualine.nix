{ ... }:

{
  programs.nixvim.plugins.lualine = {
    enable = true;

    disabledFiletypes.statusline = [ "neo-tree" ];

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
