{...}: {
  flake.modules.nixos.networking = {
    services.connman = {
      enable = true;
      wifi.backend = "iwd";
    };

    systemd.tmpfiles.rules = [
      "L /var/lib/connman - - - - /persist/var/lib/connman"
    ];

    networking.firewall.enable = true;
  };
}
