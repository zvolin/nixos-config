{ ... }:

{
  nixpkgs.overlays = [
    # todo: https://github.com/NixOS/nixpkgs/pull/308876
    # (import ./kitty-themes.nix { inherit inputs; })
    # (import ./waybar.nix { inherit inputs; })
    # (import ./hyprland.nix { })
  ];
}
