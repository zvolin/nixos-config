{ lib, ... }:
{
  # The sd-image module + raspberry-pi-4 profile own partitioning, the root
  # filesystem, auto-expand, boot, and initrd modules. All this host file pins is
  # the platform. mkDefault so the sd-image module's own hostPlatform wins if it
  # sets one.
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
