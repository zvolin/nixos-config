{ ... }:

{
  programs.nixvim.plugins.bufferline = {
    enable = true;

    diagnostics = "nvim_lsp";
    separatorStyle = "slant";

    # overwrite default close command which messes up windows
    closeCommand = "Bdelete %d";

    # only put bufferline after side panels
    offsets = map (filetype: {
      inherit filetype;
      separator = true;
      text-align = "left";
    }) [ "neo-tree" "undotree" ];
  };
}
