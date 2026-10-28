{ inputs, ... }:
{
  flake.modules.nixos.system-minimal = {
    imports = with inputs.self.modules.nixos; [
      nix-settings
      i18n
      home-manager-integration
      unfree
      security
      nftables
    ];

    time.timeZone = "Europe/Warsaw";
  };
}
