{ inputs, ... }:

final: prev: { waybar = inputs.nixpkgs-master.legacyPackages.${prev.system}.waybar; }
