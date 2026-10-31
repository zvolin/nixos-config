{ ... }:
{
  # Local-only alarm path: dead box or dead ntfy has no alert.
  flake.modules.nixos.nas-storage-health =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      members = import ./_tank-members.nix;

      push = lib.getExe config.homelab.ntfy.postPackage;
      topic = config.homelab.ntfy.topics.health; # By name so topic renames carry the ACL.

      smartNotify = pkgs.writeShellScript "smartd-ntfy" ''
        ${push} ${topic} "nas SMART alert" high "warning,floppy_disk" "$SMARTD_MESSAGE"
      '';

      # ZED runs with minimal PATH. Pool-level faults match no arm (caught by hourly backstop).
      statechangeNtfy = pkgs.writeShellScript "statechange-ntfy.sh" ''
        case "$ZEVENT_VDEV_STATE_STR" in
          DEGRADED|FAULTED|UNAVAIL|REMOVED)
            ${push} ${topic} "nas ZFS: $ZEVENT_POOL vdev $ZEVENT_VDEV_STATE_STR" high "rotating_light" \
              "pool=$ZEVENT_POOL vdev=$ZEVENT_VDEV_PATH state=$ZEVENT_VDEV_STATE_STR"
            ;;
        esac
      '';

      # `zpool status -x` exits 0 always, parse text. Guard: skip if tank un-imported (zfs.target race).
      zpoolBackstop = pkgs.writeShellScript "zpool-status-backstop" ''
        zpool list tank >/dev/null 2>&1 || exit 0
        if ! zpool status -x tank | grep -q "is healthy"; then
          ${push} ${topic} "nas ZFS: tank not healthy" high "rotating_light" "$(zpool status tank 2>&1)"
        fi
      '';
    in
    {
      # -m <nomailer> satisfies -M exec's -m requirement without MTA. autodetect=false: four pinned tank members only.
      services.smartd = {
        enable = true;
        autodetect = false;
        devices = lib.mapAttrsToList (_: device: { inherit device; }) members;
        defaults.monitored = "-a -o on -s (S/../.././02|L/../../6/03) -m <nomailer> -M exec ${smartNotify}";
      };

      # Name differs from stock statechange-notify.sh; ZED dispatches both.
      environment.etc."zfs/zed.d/statechange-ntfy.sh" = {
        source = statechangeNtfy;
        mode = "0555";
      };

      systemd.services.zpool-status-backstop = {
        description = "Push an ntfy alarm when tank is not reported healthy";
        after = [ "zfs.target" ];
        path = [
          config.boot.zfs.package
          pkgs.gnugrep
        ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = zpoolBackstop;
        };
      };
      systemd.timers.zpool-status-backstop = {
        wantedBy = [ "timers.target" ];
        # No Persistent: hourly health poll needs no missed-tick catch-up.
        timerConfig = {
          OnCalendar = "hourly";
        };
      };
    };
}
