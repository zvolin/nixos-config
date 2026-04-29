{inputs, ...}: {
  flake.modules.nixos.nixvim = {
    imports = [
      inputs.nixvim.nixosModules.nixvim
      ./_internals/autocmd.nix
      ./_internals/keymaps.nix
      ./_internals/options.nix
      ./_internals/plugins
      ./_internals/utils.nix
    ];

    programs.nixvim = {
      enable = true;
      viAlias = true;
      vimAlias = true;
    };

    home-manager.sharedModules = [inputs.nixvim.homeModules.nixvim];
  };
}
