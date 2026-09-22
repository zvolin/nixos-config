{ ... }:
{
  # Enable Flatpak system-wide (nixpkgs' own module). Declarative --user package
  # installs are layered on top by nix-flatpak's home-manager module (see
  # modules/programs/bambu-studio.nix). Portals already exist via the Hyprland HM
  # module (xdg-desktop-portal-gtk). Imported by the host like `docker`.
  flake.modules.nixos.flatpak = {
    services.flatpak.enable = true;
  };
}
