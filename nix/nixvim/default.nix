{ pkgs, ... }:

{
  imports = [
    ./autocmd.nix
    ./keymaps.nix
    ./options.nix
    ./plugins
    ./utils.nix
  ];

  programs.nixvim = {
    enable = true;
    viAlias = true;
    vimAlias = true;

    package = pkgs.neovim-unwrapped.overrideAttrs {
      patches = [
        ./308e9719cf4b7c55c27e7bdc867e13501cc717e3.patch
      ];
    };
  };
}
