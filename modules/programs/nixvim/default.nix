{ inputs, ... }:
{
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
      # We follow a single nixpkgs (see flake.nix); make that explicit so nixvim
      # doesn't warn about its pinned nixpkgs being overridden by `follows`.
      nixpkgs.source = inputs.nixpkgs;
    };

    home-manager.sharedModules = [ inputs.nixvim.homeModules.nixvim ];
  };
}
