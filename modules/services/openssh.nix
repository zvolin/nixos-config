{ ... }:
{
  flake.modules.nixos.openssh = {
    # sshd stays enabled but dormant. The live remote path is Tailscale SSH
    # (served by tailscaled, which intercepts tailnet :22 at the daemon level),
    # so hardening this leg does not break `ssh mbp-m2` over the tailnet:
    #   - openFirewall = false: no public TCP 22 on any interface.
    #   - PasswordAuthentication = false and KbdInteractiveAuthentication = false:
    #     no password login even if reached.
    # See modules/services/tailscale.nix for the tailnet endpoint and the
    # documented plain-SSH fallback (which would require re-adding a key).
    services.openssh = {
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
