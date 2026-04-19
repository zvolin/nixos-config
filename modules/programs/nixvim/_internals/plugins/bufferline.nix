{ ... }:

{
  programs.nixvim.plugins.bufferline = {
    enable = true;

    settings.options = {
      diagnostics = "nvim_lsp";
      separator_style = "slant";

      # overwrite default close command which messes up windows
      close_command = "Bdelete %d";

      # only put bufferline after side panels
      offsets =
        map
          (filetype: {
            inherit filetype;
            separator = true;
            text-align = "left";
          })
          [
            "neo-tree"
            "undotree"
          ];
    };
  };
}
