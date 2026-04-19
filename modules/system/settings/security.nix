{ ... }:

{
  flake.modules.nixos.security = {
    security.pam.services.swaylock = { };
  };
}
