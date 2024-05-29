{ ... }:

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
  };
}
