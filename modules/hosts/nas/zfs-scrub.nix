{ ... }:
{
  flake.modules.nixos.nas-zfs-scrub =
    { ... }:
    {
      services.zfs.autoScrub = {
        enable = true;
        interval = "monthly";
        pools = [ "tank" ];
      };
    };
}
