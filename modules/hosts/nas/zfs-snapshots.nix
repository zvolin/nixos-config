{ ... }:
{
  flake.modules.nixos.nas-zfs-snapshots =
    { pkgs, ... }:
    {
      # Leaf-only to skip canmount=off containers; postgres snapshots are crash-consistent only (not a backup).
      services.sanoid = {
        enable = true;
        templates.authoritative = {
          hourly = 36;
          daily = 30;
          monthly = 3;
          autosnap = true;
          autoprune = true;
        };
        templates.media = {
          hourly = 0;
          daily = 7;
          monthly = 0;
          autosnap = true;
          autoprune = true;
        };
        datasets."tank/data/files" = {
          useTemplate = [ "authoritative" ];
        };
        datasets."tank/data/documents" = {
          useTemplate = [ "authoritative" ];
        };
        datasets."tank/data/immich/library" = {
          useTemplate = [ "authoritative" ];
        };
        datasets."tank/data/postgres" = {
          useTemplate = [ "authoritative" ];
        };
        datasets."tank/data/media" = {
          useTemplate = [ "media" ];
        };
      };

      environment.systemPackages = [ pkgs.httm ];
    };
}
