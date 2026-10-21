{ inputs, ... }:
{
  flake.modules.nixos.system-desktop =
    { pkgs, ... }:
    {
      imports = with inputs.self.modules.nixos; [
        system-cli
        hyprland
        pipewire
        greetd
      ];

      services.xserver.enable = true;

      services.dbus.packages = [ pkgs.mako ];

      programs.wireshark.enable = true;

      programs.gnupg.agent = {
        enable = true;
        enableSSHSupport = true;
      };
    };
}
