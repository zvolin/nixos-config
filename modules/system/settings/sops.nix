{ inputs, ... }:
{
  # Wraps sops-nix so a host gets secret management by importing `sops` alone.
  # User- and secret-specific wiring lives with each consumer (e.g. zwolin-sops),
  # keeping this aspect reusable across hosts and users.
  flake.modules.nixos.sops = {
    imports = [ inputs.sops-nix.nixosModules.sops ];

    # Install regular secrets (and run their restartUnits) from a systemd unit
    # instead of the activation script. NixOS removes activation-script unit
    # restarts in 26.11, so the backend must move now.
    sops.useSystemdActivation = true;
  };
}
