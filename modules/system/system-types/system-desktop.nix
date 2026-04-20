{ inputs, ... }:

{
  flake.modules.nixos.system-desktop = { pkgs, ... }: {
    imports = with inputs.self.modules.nixos; [
      system-cli
      hyprland
      pipewire
      greetd
    ];

    services.xserver.enable = true;

    services.dbus.packages = [ pkgs.mako ];
  };
}
