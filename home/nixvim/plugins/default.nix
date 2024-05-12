{ lib, pkgs, config, ... }:

{
  imports = [
    ./cmp.nix
    ./lualine.nix
    ./neotree.nix
    ./nvim-colorizer.nix
    ./nvim-window-picker.nix
    ./toggleterm.nix
    ./which-key.nix
  ];

  programs.nixvim.plugins = {
    lsp.enable = true;
    luasnip.enable = true;
    telescope.enable = true;
    treesitter.enable = true;
    rustaceanvim.enable = true;
  };
}
