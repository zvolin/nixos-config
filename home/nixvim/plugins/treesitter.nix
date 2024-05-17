{ ... }:

{
  programs.nixvim.plugins.treesitter = {
    enable = true;
    indent = true;
    # eg. highlights lua code in extraConfigLua
    nixvimInjections = true;
  };
}
