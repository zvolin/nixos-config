{ ... }:

final: prev: {
  hyprland = prev.hyprland.overrideAttrs {
     patches = [
        ./0001-linux-dmabuf-allow-on-split-node-systems.patch
     ];
  };
}
