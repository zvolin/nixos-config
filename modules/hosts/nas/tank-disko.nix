{ inputs, ... }:
let
  poolName = "tank";

  members = import ./_tank-members.nix;

  # Standalone disko spec. NOT a NixOS module and NOT imported into
  # nixosConfigurations.nas, so a nas rebuild/switch can never run a disko
  # format/destroy script against the array. Consumed only by create-nas-pool.
  diskoConfig = {
    disko.devices = {
      disk = builtins.mapAttrs (_: device: {
        type = "disk";
        inherit device;
        content = {
          type = "zfs";
          pool = poolName;
        };
      }) members;

      zpool.${poolName} = {
        type = "zpool";
        mode = "raidz1";
        options.ashift = "12"; # 4K sectors (2^12) for the Advanced Format array drives
        # -O pool-wide options, inherited by every dataset. tank root stays UNENCRYPTED.
        rootFsOptions = {
          canmount = "off";
          mountpoint = "/${poolName}";
          compression = "lz4";
          xattr = "sa";
          atime = "off";
          acltype = "posixacl";
          dnodesize = "auto";
        };
        datasets = {
          # The single encryptionroot; every tank/data* child inherits this key.
          "data" = {
            type = "zfs_fs";
            options = {
              canmount = "off";
              encryption = "on";
              keyformat = "passphrase";
              keylocation = "file:///run/secrets/zfs/tank-passphrase";
            };
          };
          # recordsize=1M: bulk-sequential large media, same workload as immich/library.
          # Keep downloads/import staging as directories INSIDE this dataset, never a
          # separate one — *arr atomic-moves and hardlinks work only within a single
          # dataset, so a split silently turns every import into a full copy.
          "data/media" = {
            type = "zfs_fs";
            options.recordsize = "1M";
          };
          "data/immich" = {
            type = "zfs_fs";
          };
          "data/immich/library" = {
            type = "zfs_fs";
            options.recordsize = "1M";
          };
          # recordsize=8k matches PostgreSQL's 8 KiB page; logbias=throughput suits its
          # write pattern. These pair with full_page_writes=off, which belongs in the
          # postgres server config (a postgres setting, not a ZFS property to zfs set).
          "data/postgres" = {
            type = "zfs_fs";
            options = {
              recordsize = "8k";
              compression = "zstd";
              logbias = "throughput";
            };
          };
          "data/files" = {
            type = "zfs_fs";
            options.recordsize = "128k";
          };
          "data/documents" = {
            type = "zfs_fs";
          };
        };
      };
    };
  };
in
{
  perSystem =
    { system, lib, ... }:
    let
      pkgs = import inputs.nixpkgs { inherit system; };
      # _cliFormat -> $out/bin/disko-format: create-only (no destroy, no mount),
      # rootMountPoint=/mnt. Bundles zfs/util-linux for the TARGET, so it must be
      # built where it runs: nas (x86_64). The aarch64 Mac has no binfmt, hence the
      # x86_64-only gate; validate on the Mac with nix eval + dry-build.
      # The emitted zpool/zfs commands are not frozen by the eval: a disko bump can
      # change them. Re-verify on a bump (the runbook trusts this, so there is no
      # per-run inspection): `nix derivation show .#packages.x86_64-linux.create-nas-pool`
      # prints the generated script text without needing an x86_64 build.
      createPool = inputs.disko.lib._cliFormat diskoConfig pkgs;
    in
    {
      apps = lib.optionalAttrs (system == "x86_64-linux") {
        create-nas-pool = {
          type = "app";
          program = lib.getExe createPool;
          meta.description = "Create the nas tank raidz1 pool and encrypted dataset tree (run on nas after the sops passphrase is deployed)";
        };
      };
      packages = lib.optionalAttrs (system == "x86_64-linux") {
        create-nas-pool = createPool;
      };
    };
}
