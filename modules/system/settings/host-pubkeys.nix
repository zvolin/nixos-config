{ inputs, ... }:
{
  # Every host/client public key plus the trust topology, read at eval from the
  # private secrets input: the user-key `keys`, the `authorized` mesh, and the
  # `hostKeys` that seed the known-hosts baseline. A separate registry from
  # `lanConfig` (network topology) — both now sourced from the private input, but
  # split by concern: keys here, addresses there. Pure readFile + fromJSON,
  # never IFD.
  flake.lib.hostPubKeys = builtins.fromJSON (builtins.readFile "${inputs.secrets}/pubkeys.json");
}
