{ inputs, ... }:
let
  poolName = "tank";
  encryptionRoot = "tank/data";
  passphraseSecret = "zfs/tank-passphrase"; # → /run/secrets/zfs/tank-passphrase
in
{
  flake.modules.nixos.nas-zfs-pool =
    { config, ... }:
    {
      imports = [ inputs.self.modules.nixos.sops ];

      # ZFS needs a stable 32-bit host id, recorded in the pool at creation so a
      # hostId match imports it without -f (forceImportAll defaults off). Must be
      # deployed before the pool is created.
      networking.hostId = "af9a0dec";

      boot.supportedFilesystems = [ "zfs" ];
      # Hygiene only: forceImportRoot governs the initrd ROOT-pool import (never runs
      # here — ext4 root) and silences the 26.11 default-value warning. It does NOT
      # affect tank: the extraPools import service force-imports only when
      # boot.zfs.forceImportAll is true (default false), so tank's recorded hostId
      # matching the host's is what imports it without -f.
      boot.zfs.forceImportRoot = false;
      boot.zfs.extraPools = [ poolName ]; # import tank at boot (native mountpoints)
      # boot.zfs.devNodes defaults to /dev/disk/by-id — the by-id import mechanism.

      # Without this, the stock early zfs-import-tank.service runs `zfs load-key`
      # reading /run/secrets before sops has populated it. Disable the early
      # key-load; a dedicated sops-ordered unit does it instead.
      boot.zfs.requestEncryptionCredentials = false;

      sops.secrets.${passphraseSecret}.sopsFile = "${inputs.secrets}/shared.yaml";

      # The ordering below works only because sops.useSystemdActivation = true (set in
      # modules/system/settings/sops.nix) makes sops-install-secrets.service exist.
      # Under sops-nix's default (false) secrets install via an activation script, no
      # such unit exists, and the after/wants become silent no-ops that race secret
      # delivery at boot. Assert it so a revert fails loudly at build, not at boot.
      assertions = [
        {
          assertion = config.sops.useSystemdActivation;
          message = "nas-zfs-pool: zfs-load-key-tank orders after sops-install-secrets.service, which only exists when sops.useSystemdActivation = true (sops-nix default is false).";
        }
      ];

      # Load the encryptionroot key after sops, then mount. Decoupled from the stock
      # zfs-mount.service (Before=local-fs.target, early) because sops-install-secrets
      # is After=local-fs.target (late) — ordering key-load between them is a cycle.
      systemd.services."zfs-load-key-${poolName}" = {
        description = "Load sops key for ${encryptionRoot} and mount ${poolName}";
        after = [
          "zfs-import-${poolName}.service"
          "sops-install-secrets.service"
        ];
        requires = [ "zfs-import-${poolName}.service" ];
        wants = [ "sops-install-secrets.service" ];
        wantedBy = [ "zfs.target" ];
        unitConfig.ConditionPathIsDirectory = "/sys/module/zfs";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        path = [ config.boot.zfs.package ];
        script = ''
          [ "$(zfs get -H -o value keystatus ${encryptionRoot})" = unavailable ] \
            && zfs load-key ${encryptionRoot}
          zfs mount -a
        '';
      };
    };
}
