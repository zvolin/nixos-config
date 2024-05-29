{ ... }:

{
  programs.nixvim.plugins.toggleterm = {
    enable = true;

    settings = {
      direction = "float";
      open_mapping = "[[<C-t>]]";
      float_opts.border = "curved";
    };
  };
}
