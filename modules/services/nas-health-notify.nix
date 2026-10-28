{ inputs, ... }:
{
  # Adds nas-health-push for manual degrade-alarm testing.
  flake.modules.nixos.nas-health-notify =
    { config, pkgs, ... }:
    let
      nasHealth = import ./_nas-health-push.nix {
        inherit pkgs;
        credentialFile = config.sops.secrets."ntfy/publisher-password".path;
      };
    in
    {
      imports = [ inputs.self.modules.nixos.ntfy-publisher-secret ];

      environment.systemPackages = [ nasHealth.package ];
    };
}
