{ inputs, ... }:
{
  flake.modules.nixos.nas-kopia-backup =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      settings = import ./_kopia-settings.nix;

      kopiaBin = lib.getExe pkgs.kopia;
      # --cache-directory is a create/connect-only flag, not global; other commands read the
      # cache path from the config. Passing it globally makes kopia reject every subcommand.
      kopiaFlags = "--config-file=${settings.configFile}";

      sources = config.homelab.backup.sources;

      policyLines = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (_: src: ''
          ${kopiaBin} ${kopiaFlags} policy set ${lib.escapeShellArg src.path} \
            --keep-daily=${toString settings.keepDaily} \
            --keep-weekly=${toString settings.keepWeekly} \
            --keep-monthly=${toString settings.keepMonthly}${
              lib.optionalString (src.preSnapshotAction != null) ''
                \
                           --before-snapshot-root-action=${lib.escapeShellArg src.preSnapshotAction} \
                           --action-command-mode=essential''
            }
        '') sources
      );

      # Runs as ExecStartPre, never at activation, so B2 stays off the `switch` path.
      reconcileScript = pkgs.writeShellApplication {
        name = "kopia-reconcile";
        runtimeInputs = [
          pkgs.kopia
          pkgs.coreutils
        ];
        text = ''
          export KOPIA_PASSWORD
          KOPIA_PASSWORD="$(cat "$CREDENTIALS_DIRECTORY/kopia-repository-password")"
          if ! ${kopiaBin} ${kopiaFlags} repository status >/dev/null 2>&1; then
            ${kopiaBin} ${kopiaFlags} repository connect from-config \
              --file=${settings.configFile} --cache-directory=${settings.cacheDir} --enable-actions
          fi
          ${policyLines}
          ${kopiaBin} ${kopiaFlags} maintenance set \
            --owner=${settings.maintenanceOwner} --extend-object-locks=true
        '';
      };

      credPassword = config.sops.secrets."backup/kopia-repository-password".path;

      # ConditionPathExists is a [Unit] directive (unitConfig, NOT serviceConfig — systemd
      # silently ignores it there); it self-skips every unit until the repo exists.
      backupUnitCommon = {
        unitConfig.ConditionPathExists = settings.configFile;
        onFailure = [ "kopia-notify@%n.service" ];
        serviceConfig = {
          Type = "oneshot";
          LoadCredential = [ "kopia-repository-password:${credPassword}" ];
          ExecStartPre = "${lib.getExe reconcileScript}";
        };
      };

      # Per-source units: an essential pre-snapshot failure fails only that source.
      mkSnapshotService =
        name: src:
        let
          snapshotScript = pkgs.writeShellApplication {
            name = "kopia-snapshot-${name}";
            runtimeInputs = [
              pkgs.kopia
              pkgs.coreutils
            ];
            text = ''
              export KOPIA_PASSWORD
              KOPIA_PASSWORD="$(cat "$CREDENTIALS_DIRECTORY/kopia-repository-password")"
              ${kopiaBin} ${kopiaFlags} snapshot create ${lib.escapeShellArg src.path}
            '';
          };
        in
        lib.recursiveUpdate backupUnitCommon {
          description = "Kopia snapshot of source ${name}";
          serviceConfig.ExecStart = lib.getExe snapshotScript;
        };
      snapshotServices = lib.mapAttrs' (
        name: src: lib.nameValuePair "kopia-snapshot-${name}" (mkSnapshotService name src)
      ) sources;
      snapshotTimers = lib.mapAttrs' (
        name: _:
        lib.nameValuePair "kopia-snapshot-${name}" {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = settings.snapshotOnCalendar;
            Persistent = true; # catch up a missed daily snapshot after downtime
          };
        }
      ) sources;

      # Full maintenance extends object locks; stamp on success feeds the staleness backstop.
      maintenanceScript = pkgs.writeShellApplication {
        name = "kopia-maintenance";
        runtimeInputs = [
          pkgs.kopia
          pkgs.coreutils
        ];
        text = ''
          export KOPIA_PASSWORD
          KOPIA_PASSWORD="$(cat "$CREDENTIALS_DIRECTORY/kopia-repository-password")"
          ${kopiaBin} ${kopiaFlags} maintenance run --full
          touch ${settings.maintenanceStamp}
        '';
      };

      push = lib.getExe config.homelab.ntfy.postPackage;
      healthTopic = config.homelab.ntfy.topics.health;
      alarmPriority = "high";
      alarmIcon = "rotating_light";

      # The failing unit's name arrives as %i (from onFailure=…@%n.service).
      notifyScript = pkgs.writeShellScript "kopia-notify" ''
        ${push} ${healthTopic} "nas Kopia: $1 failed" ${alarmPriority} "${alarmIcon}" \
          "$1 failed on nas — check journalctl -u $1"
      '';

      # Threshold derived in _kopia-settings.nix (≈2 missed cycles + grace), below the
      # correctness ceiling so the alarm fires with lead to spare.
      backstopScript = pkgs.writeShellScript "kopia-maintenance-backstop" ''
        stamp=${settings.maintenanceStamp}
        if [ ! -e "$stamp" ]; then
          # Backstop runs unconditionally, so it must itself tell "never provisioned / fully
          # wiped" (no config, no stamp → nothing to guard, stay quiet) from a lost stamp on a
          # live repo (config present → real fault).
          [ -e "${settings.configFile}" ] || exit 0
          ${push} ${healthTopic} "nas Kopia: maintenance stamp missing" ${alarmPriority} "${alarmIcon}" \
            "$stamp absent — full maintenance has not completed since repo create"
          exit 0
        fi
        age=$(( $(date +%s) - $(stat -c %Y "$stamp") ))
        if [ "$age" -gt ${toString settings.maintenanceStaleThresholdSecs} ]; then
          ${push} ${healthTopic} "nas Kopia: maintenance stale" ${alarmPriority} "${alarmIcon}" \
            "last full maintenance ''${age}s ago (> ${toString settings.maintenanceStaleThresholdSecs}s) — object locks may be lapsing"
        fi
      '';
    in
    {
      options.homelab.backup.sources = lib.mkOption {
        default = { };
        description = "Kopia snapshot sources. Each becomes a source with a GFS retention policy.";
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              path = lib.mkOption {
                type = lib.types.str;
                description = "Absolute path snapshotted for this source.";
              };
              preSnapshotAction = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Executable run before the snapshot (DB-dump seam). Kopia sets $KOPIA_SOURCE_PATH; the script writes its dump into that path. Mode essential.";
              };
            };
          }
        );
      };

      config = {
        # Database-dump sources are added later via the preSnapshotAction seam.
        homelab.backup.sources = {
          files.path = "/tank/data/files";
          documents.path = "/tank/data/documents";
          immich-library.path = "/tank/data/immich/library";
        };

        sops.secrets."backup/b2-application-key".sopsFile = "${inputs.secrets}/shared.yaml";
        sops.secrets."backup/kopia-repository-password".sopsFile = "${inputs.secrets}/shared.yaml";

        # /var/lib/kopia must exist before the HITL create app (which is not a unit) runs.
        systemd.tmpfiles.rules = [ "d ${settings.stateDir} 0700 root root -" ];

        # Local-file probe only — the sole thing on the activation path.
        homelab.provisioningGuards.kopia-repo = {
          check = "test -e ${settings.configFile}";
          runbook = "docs/runbooks/nas-kopia-backup.md";
        };

        systemd.services = snapshotServices // {
          kopia-maintenance = lib.recursiveUpdate backupUnitCommon {
            description = "Kopia full maintenance (extends object locks)";
            serviceConfig.ExecStart = lib.getExe maintenanceScript;
          };

          "kopia-notify@" = {
            description = "Push an ntfy alarm when %i fails";
            serviceConfig = {
              Type = "oneshot";
              ExecStart = "${notifyScript} %i";
            };
          };
          # No ConditionPathExists: unlike the snapshot/maintenance units this one must run
          # even when repository.config is gone, or losing the config would silence the very
          # alarm meant to catch it. The script decides quiet-vs-alarm itself.
          kopia-maintenance-backstop = {
            description = "Alarm when Kopia full maintenance is missing or stale";
            serviceConfig = {
              Type = "oneshot";
              ExecStart = backstopScript;
            };
          };
        };
        systemd.timers = snapshotTimers // {
          kopia-maintenance = {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = settings.maintenanceOnCalendar;
              Persistent = true; # a missed full-maintenance run is what the staleness alarm guards against
            };
          };

          kopia-maintenance-backstop = {
            wantedBy = [ "timers.target" ];
            # No Persistent: a periodic liveness poll needs no missed-tick catch-up.
            timerConfig.OnCalendar = "hourly";
          };
        };
      };
    };
}
