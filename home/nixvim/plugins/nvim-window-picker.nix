{ pkgs, ... }:

{
  programs.nixvim = {
    extraPlugins = with pkgs.vimPlugins; [
      nvim-window-picker
    ];

    extraConfigLua = ''
      require 'window-picker'.setup({
        -- switch selection chars to dvorak home row
        selection_chars = 'uhetonas';
      })
    '';
  };
}
