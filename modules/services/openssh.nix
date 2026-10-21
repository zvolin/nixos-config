{ ... }:
{
  flake.modules.nixos.openssh =
    { config, lib, ... }:
    {
      # A seam for directing where sshd and sops-nix both read the host key. Default
      # is /etc/ssh; impermanent hosts override to /persist/etc/ssh (see impermanence.nix)
      # so keys survive the root wipe. sops-nix derives its age identity from
      # services.openssh.hostKeys, so both follow this one value.
      options.sshHostKeyDir = lib.mkOption {
        type = lib.types.str;
        default = "/etc/ssh";
        description = "Directory holding the SSH host keys.";
      };

      # sshd stays enabled but dormant. The live remote path is Tailscale SSH
      # (served by tailscaled, which intercepts tailnet :22 at the daemon level),
      # so hardening this leg does not break `ssh mbp-m2` over the tailnet:
      #   - openFirewall = false: no public TCP 22 on any interface.
      #   - PasswordAuthentication = false and KbdInteractiveAuthentication = false:
      #     no password login even if reached.
      # See modules/services/tailscale.nix for the tailnet endpoint and the
      # documented plain-SSH fallback (which would require re-adding a key).
      config.services.openssh = {
        enable = true;
        openFirewall = false;
        settings = {
          PasswordAuthentication = false;
          # PasswordAuthentication=false alone still leaves the door open: sshd
          # offers keyboard-interactive by default, and PAM happily accepts the
          # Unix password through that path. Turn it off too so it's key-only.
          KbdInteractiveAuthentication = false;
        };
        hostKeys = [
          {
            path = "${config.sshHostKeyDir}/ssh_host_ed25519_key";
            type = "ed25519";
          }
          {
            path = "${config.sshHostKeyDir}/ssh_host_rsa_key";
            type = "rsa";
            bits = 4096;
          }
        ];
      };
    };
}
