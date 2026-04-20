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
      settings.sign.enabled = false;
    };
  };

  programs.nixvim.extraPlugins = with pkgs.vimPlugins; [
    undotree
    bufdelete-nvim
  ];
}
