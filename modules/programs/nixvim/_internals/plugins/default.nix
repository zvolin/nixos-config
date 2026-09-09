{ pkgs, ... }:
{
  imports = [
    ./bufferline.nix
    ./cmp.nix
    ./comment.nix
    ./hardtime.nix
    ./lsp.nix
    ./lualine.nix
    ./neotree.nix
    ./nvim-window-picker.nix
    # ./telescope-manix.nix
    ./telescope.nix
    ./toggleterm.nix
    ./treesitter.nix
    ./which-key.nix
  ];

  programs.nixvim.plugins = {
    luasnip.enable = true;
    rustaceanvim.enable = true;
    render-markdown = {
      enable = true;
      # nixvim resolves `package` from its own vendored plugin set, not
      # pkgs.vimPlugins, so the overlay-render-markdown override is invisible
      # unless we point this option at the overlaid (fork) derivation.
      package = pkgs.vimPlugins.render-markdown-nvim;
      settings = {
        sign.enabled = false;
        # Enable the vendored cell-wrapping feature. It stays off until
        # max_table_width is non-zero (and the window has `wrap`, set for
        # markdown in autocmd.nix). Caps table width to the window and wraps
        # overflowing cell content onto virtual lines. 1.0 = full window width;
        # use e.g. 0.9 or -2 to leave a right margin. 0 (default) = disabled.
        pipe_table.max_table_width = 1.0;
      };
    };
  };

  programs.nixvim.extraPlugins = with pkgs.vimPlugins; [
    undotree
    bufdelete-nvim
  ];
}
