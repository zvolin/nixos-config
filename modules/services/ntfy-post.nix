{ inputs, ... }:
{
  flake.modules.nixos.ntfy-post =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      imports = [ inputs.self.modules.nixos.sops ];

      options.homelab.ntfy.postPackage = lib.mkOption {
        type = lib.types.package;
        internal = true;
        description = "The ntfy-post CLI, built for this host (loopback-vs-remote + cred baked in). Consume via lib.getExe.";
      };

      options.homelab.ntfy.topics = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        internal = true;
        default = inputs.self.lib.ntfy.topics;
        description = "ntfy topic names from the facts seam, readable by consumers (osConfig/config) that only import this aspect.";
      };

      config = {
        # Root reads this via systemd LoadCredential (DAC bypass); producers must not re-own it to root or zwolin's read breaks.
        sops.secrets."ntfy/publisher-password" = {
          sopsFile = "${inputs.secrets}/shared.yaml";
          owner = "zwolin";
          mode = "0400";
        };

        homelab.ntfy.postPackage =
          (import ./_ntfy-post.nix {
            inherit pkgs;
            ntfy = inputs.self.lib.ntfy;
            isServer = config.services.ntfy-sh.enable;
            credentialFile = config.sops.secrets."ntfy/publisher-password".path;
          }).package;

        environment.systemPackages = [ config.homelab.ntfy.postPackage ];
      };
    };
}
