{ inputs, ... }:
{
  # Root reads this via systemd LoadCredential (DAC bypass); producers must not re-own it to root or zwolin's read breaks.
  flake.modules.nixos.ntfy-publisher-secret =
    { ... }:
    {
      imports = [ inputs.self.modules.nixos.sops ];

      sops.secrets."ntfy/publisher-password" = {
        sopsFile = "${inputs.secrets}/shared.yaml";
        owner = "zwolin";
        mode = "0400";
      };
    };
}
