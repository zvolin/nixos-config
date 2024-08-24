{ inputs, ... }:

final: prev: { kitty-themes = inputs.nixpkgs-zvolin.legacyPackages.${prev.system}.kitty-themes; }
