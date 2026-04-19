{ ... }:

{
  programs.nixvim.plugins.treesitter = {
    enable = true;
    settings = {
      indent.enable = true;
      highlight.enable = true;
    };
    # eg. highlights lua code in extraConfigLua
    nixvimInjections = true;
  };
}
