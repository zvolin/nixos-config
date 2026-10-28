{ ... }:
{
  flake.modules.nixos.docker = {
    virtualisation = {
      containers.enable = true;
      docker.enable = true;
    };
  };
}
