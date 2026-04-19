{ ... }:

{
  flake.modules.nixos.openssh = {
    services.openssh = {
      enable = true;
      settings.PasswordAuthentication = true;
      hostKeys = [
        {
          path = "/persist/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
        {
          path = "/persist/etc/ssh/ssh_host_rsa_key";
          type = "rsa";
          bits = 4096;
        }
      ];
    };
  };
}
