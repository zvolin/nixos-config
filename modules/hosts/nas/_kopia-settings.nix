# Single source of truth for the Kopia aspect and the create app (not auto-discovered;
# imported explicitly by both, like _tank-members.nix).
let
  # Full-maintenance cadence (the lock-extension-bearing run) in seconds; the staleness
  # alarm derives from it, so "a cycle" has one source of truth.
  fullMaintenanceIntervalSecs = 86400; # 1 day
  maintenanceStaleCycles = 2; # alarm after ~2 missed full-maintenance cycles
  maintenanceGraceSecs = 7200; # 2h slack
in
{
  # B2 target. Object lock works only over the S3 API, not native b2:.
  bucket = "tank-worm-7f3a9c";
  endpoint = "s3.eu-central-003.backblazeb2.com";
  region = "eu-central-003";
  accessKeyId = "0030f4087f1c89e0000000001"; # non-secret S3 access-key-id
  prefix = "nas/"; # repo lives under this bucket prefix, so it coexists with the oltest/ validation repo

  # Kopia state (nas is not impermanent; /var/lib survives reboot).
  stateDir = "/var/lib/kopia";
  configFile = "/var/lib/kopia/repository.config";
  cacheDir = "/var/lib/kopia/cache";
  maintenanceStamp = "/var/lib/kopia/.last-full-maintenance";
  maintenanceOwner = "root@nas";

  # Retention — GFS snapshot-retention tiers, applied per source.
  keepDaily = 7;
  keepWeekly = 4;
  keepMonthly = 3; # longest tier ≈ 3 months ≈ 92 days

  # Object-lock immutability floor (repo-wide), days. Invariants (Kopia + slack):
  # fullMaintenance ≤ retentionPeriodDays − 1 day, and retentionPeriodDays ≥
  # longestTierDays + k × fullMaintenanceDays so k missed full-maintenance cycles cannot
  # lapse a still-referenced lock. Plan-gate affirmed.
  retentionPeriodDays = 110; # 92 (3 mo) + ~18 d slack ≈ 18 missed daily full-maintenance cycles

  # Timer cadence (wall-clock) and the DERIVED staleness threshold — all consumed
  # downstream, so there are no re-hardcoded numbers to drift.
  snapshotOnCalendar = "02:00";
  maintenanceOnCalendar = "04:00";
  maintenanceStaleThresholdSecs =
    fullMaintenanceIntervalSecs * maintenanceStaleCycles + maintenanceGraceSecs; # 180000 = 50h
}
