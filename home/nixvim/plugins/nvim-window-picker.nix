{ pkgs, config, ... }:

let
  colors = config.lib.stylix.colors.withHashtag;
in {
  programs.nixvim = {
    extraPlugins = with pkgs.vimPlugins; [
      nvim-window-picker
    ];

    extraConfigLua = ''
      require 'window-picker'.setup({
        -- switch selection chars to dvorak home row
        selection_chars = 'uhetonas';
        highlights = {
          statusline = {
            focused = {
              fg = '${colors.base0D}',
              bg = '${colors.base00}',
              bold = true,
            },
            unfocused = {
              fg = '${colors.base05}',
              bg = '${colors.base00}',
              bold = true,
            },
          },
        };
      })
    '';
  };
}
