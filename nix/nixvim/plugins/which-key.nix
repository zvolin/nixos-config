{ ... }:

{
  programs.nixvim.plugins.which-key = {
    enable = true;

    window.border = "rounded";
    plugins.presets = {
      g = true;
      motions = true;
      nav = true;
      operators = true;
      textObjects = true;
      windows = true;
      z = true;
    };
  };
}
