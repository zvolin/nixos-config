{ inputs, lib, ... }:
let
  # One source of truth for the LAN, read from the private secrets input so the
  # internal topology (subnet, gateway, host IPs) is not published in this repo.
  # Shape: { gateway; dns; prefixLength; hosts = { <name> = <ip>; }; }. Host
  # modules read their static IP from `hosts` and the shared gateway/DNS/prefix
  # from the top level, so a new wired host repeats none of it.
  #
  # The .10/.11 host IPs are PROVISIONAL: they assume the DHCP pool leaves them
  # free, but the pool boundary is unverified (ISP-locked panel). At install,
  # confirm they sit outside the pool (or ping-test them free) before assigning.
  lanConfig = builtins.fromJSON (builtins.readFile "${inputs.secrets}/lan.json");

  # SSH host public keys come from the private pubkey registry (the same
  # nixos-secrets map that carries the user-key mesh), keeping all host/client
  # key material in one place.
  hostKeys = inputs.self.lib.hostPubKeys.hostKeys;

  # github.com's current host key, from https://api.github.com/meta (ssh_keys).
  # An external anchor, not our key material, so it stays inline.
  githubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
in
{
  flake.lib.lanConfig = lanConfig;

  flake.modules.nixos.lan-hosts = {
    networking.hosts = lib.mapAttrs' (name: ip: lib.nameValuePair ip [ name ]) lanConfig.hosts;

    # Declarative known-hosts baseline for the host mesh + github, written to the
    # read-only /etc/ssh/ssh_known_hosts. The per-user ~/.ssh/known_hosts stays
    # writable, and ssh consults both — so hosts can still be accepted ad-hoc at
    # runtime without breaking this pinned set.
    programs.ssh.knownHosts =
      lib.mapAttrs (host: key: {
        publicKey = key;
        # nas/rpi also answer on their static LAN IP; mbp-m2 has no static IP, so
        # it is reached by name only.
        extraHostNames = lib.optional (lanConfig.hosts ? ${host}) lanConfig.hosts.${host};
      }) hostKeys
      // {
        "github.com".publicKey = githubKey;
      };
  };
}
