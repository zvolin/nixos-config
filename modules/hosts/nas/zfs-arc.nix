{ ... }:
{
  flake.modules.nixos.nas-zfs-arc =
    { ... }:
    {
      # Cap ARC at 16 GiB with a 4 GiB free-memory floor.
      boot.extraModprobeConfig = "options zfs zfs_arc_max=${
        toString (16 * 1024 * 1024 * 1024)
      } zfs_arc_sys_free=${toString (4 * 1024 * 1024 * 1024)}";
    };
}
