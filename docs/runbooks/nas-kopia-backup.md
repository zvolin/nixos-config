# nas Kopia off-site backup runbook

Provisioning the Kopia compliance-WORM backup for `nas`: the Backblaze B2 bucket and
application key, the two secrets, the repository itself, and the B2-side lifecycle rule.
Every step is run by hand — on the build machine (flake plus the private secrets
repository) or on `nas` — in order. It also covers rebuilding the off-site side from
nothing.

> **The production create is irreversible.** A compliance-locked object cannot be deleted
> until its lock lapses, so never run `create-kopia-repo` (§5) against the real bucket until
> the object-lock-extension check in §4 has passed. If data is already on `tank`, keep that
> check on a short lock window and defer the production create until it passes.

## 1. Create the Backblaze B2 bucket and application key

Do this once per off-site target, or to rebuild from nothing. Everything here is on the
Backblaze side, through the web console (the B2 and S3 CLIs can do the same).

1. **Create the bucket** with Object Lock enabled:
   - A new, private bucket with a globally unique name.
   - Enable **Object Lock** — it has to be turned on when the bucket is created. Leave the
     bucket's **default retention unset**: Kopia applies a compliance retention per object,
     and a bucket-wide default would lock objects a second way and take that control away
     from Kopia.
   - Object Lock works only over the **S3-compatible API**, not Backblaze's native `b2://`.
2. **Record the S3 endpoint and region.** The bucket's detail page shows an endpoint of the
   form `s3.<region>.backblazeb2.com` — for example `s3.eu-central-003.backblazeb2.com`,
   whose region is `eu-central-003` (the middle label of the hostname).
3. **Create a bucket-scoped application key** (App Keys → Add a New Application Key):
   - Restrict it to this one bucket, with **no expiration** (rotate it as a scheduled task
     rather than letting a key expire under the backups).
   - Grant the capability set Kopia needs for an Object-Lock bucket:
     ```
     listBuckets,readBuckets,listFiles,readFiles,writeFiles,readBucketEncryption,readBucketReplications,readBucketRetentions,readFileRetentions,writeFileRetentions,readFileLegalHolds
     ```
     `writeFileRetentions` is what lets `--extend-object-locks` renew a lock before it
     lapses; without it the extension is refused. Deleting locked objects is deliberately
     not granted — the lifecycle rule in §6 reclaims blobs once their lock lapses.
   - Backblaze shows the **keyID** and the **applicationKey** once. The keyID is not secret;
     the applicationKey is — copy it now.
4. **Point the configuration at this bucket.** In `modules/hosts/nas/_kopia-settings.nix`, set
   `bucket`, `endpoint`, `region`, and `accessKeyId` (the keyID) to the values above. These
   are non-secret and live in the Nix config; the applicationKey goes into sops in §2.

## 2. Author the secrets

The configuration reads two secrets from the private `secrets` flake input's `shared.yaml`,
which `nas` decrypts: `backup/b2-application-key` (the applicationKey from §1) and
`backup/kopia-repository-password` (the password that encrypts the Kopia repository).
`$SECRETS` below is a local checkout of that private repository.

```sh
sops set "$SECRETS/shared.yaml" '["backup"]["b2-application-key"]' '"<applicationKey>"'
sops set "$SECRETS/shared.yaml" '["backup"]["kopia-repository-password"]' '"<repository-password>"'
```

Commit and push the secrets repository, then relock this flake so `nas` picks up the new
revision:

```sh
nix flake lock --update-input secrets
```

Both are disaster-recovery credentials — escrow them (§7).

## 3. Deploy to materialize the secrets

```sh
# on nas (build-on-target):
sudo nixos-rebuild switch --flake /etc/nixos#nas
```

This writes both secrets to `/run/secrets/backup/`. Until the repository exists, the switch
prints `⚠ kopia-repo not provisioned — see docs/runbooks/nas-kopia-backup.md` and still
exits 0. A full build only succeeds once both secrets exist at the locked revision (sops
validates secret paths at build time).

## 4. Validate object-lock extension

Prove that lock extension works against this bucket before creating the production
repository. If extension silently fails, maintenance can never renew the locks it is
supposed to, and a production repo would lock (and bill for) data that can be neither
renewed nor deleted. The check uses a throwaway repository with a short lock window under the
`oltest/` prefix — parallel to the production `nas/` prefix (both repos coexist in the one
bucket, each under its own prefix), so it never touches the production data.

Run on `nas`. Put the pinned `kopia` on your PATH with
`nix shell /etc/nixos#nixosConfigurations.nas.pkgs.kopia` (the same build the aspect and the
create app use), then fill in the §1 values (`<applicationKey>` is at
`/run/secrets/backup/b2-application-key` after §3):

```sh
export KOPIA_PASSWORD="throwaway-check-password"
cfg="--config-file=/tmp/kopia-oltest.config"

# Disposable compliance repo: short window, oltest/ prefix (never the production nas/ prefix).
# --cache-directory is a create-only flag, so it goes on the create command, not in $cfg.
kopia $cfg repository create s3 \
  --bucket=<bucket> --endpoint=<endpoint> --region=<region> \
  --access-key=<keyID> --secret-access-key='<applicationKey>' \
  --cache-directory=/tmp/kopia-oltest-cache \
  --prefix=oltest/ --retention-mode=COMPLIANCE --retention-period=3d

# This is the check: Kopia refuses --extend-object-locks unless the key can write file
# retentions and the full interval is at least a day under the window.
kopia $cfg maintenance set --full-interval=24h --extend-object-locks=true
kopia $cfg maintenance info   # reports extend-object-locks as enabled
```

If `maintenance set` errors, extension is not usable yet — most often the application key
is missing `writeFileRetentions` (fix the key in §1), or the full interval is not under the
window. Resolve that before §5; a production create in this state would be unrecoverable.

Clean up afterwards. The test objects are compliance-locked for the 3-day window and cannot
be removed before it lapses; once it has, delete the `oltest/` prefix (or let the §6
lifecycle rule reclaim it). Drop the local test config:

```sh
kopia $cfg repository disconnect
rm -f /tmp/kopia-oltest.config
rm -rf /tmp/kopia-oltest-cache
```

## 5. Create the repository

Run this only after §4 passes.

```sh
sudo nix run /etc/nixos#create-kopia-repo
```

It creates the compliance-mode S3 repository under the `nas/` prefix with the retention floor
from `_kopia-settings.nix`, enables object-lock extension, sets the maintenance owner to
`root@nas`, and writes the staleness baseline stamp. It is idempotent: a re-run when the
repository already exists exits 0 and changes nothing. From then on the snapshot and
maintenance timers do the work, and a routine `switch` makes no Backblaze call.

## 6. B2 lifecycle rule

Add a lifecycle rule so expired-lock versions don't pile up and bill forever. In the bucket's
Lifecycle Settings, use **Keep prior versions for 1 day** (`daysFromHidingToDeleting = 1`),
scoped to the `nas/` prefix. **Never set "days from uploading to hiding"** — a finite value
there hides the *current* version of still-referenced blobs and corrupts the repo; kopia hides
superseded blobs itself when maintenance deletes them.

The day count can be small because the object lock, not the lifecycle rule, is the safety:
compliance mode refuses every deletion until a version's lock lapses, and kopia extends the
lock on each still-referenced blob at every maintenance run. So only unreferenced blobs stop
being renewed, and the rule reaps them one day after their lock finally lapses.

## 7. Credential custody

The Kopia repository password and the B2 application key are what a restore needs, so keep
them where they survive the loss of `nas` itself: a password manager with emergency access,
plus an offline copy held by a second person. Without both, the off-site copy cannot be
read back. Re-check the escrow on a schedule — stale custody fails silently.

## 8. Database-dump seam (for service modules)

A service that needs a consistent database dump in its backup sets
`homelab.backup.sources.<name>.preSnapshotAction = "<script>"`. The contract:

- Kopia runs `<script>` before snapshotting `<name>`, with `$KOPIA_SOURCE_PATH` set to that
  source's `path`.
- The script writes its `pg_dump` / application dump **into** `$KOPIA_SOURCE_PATH`.
- The action runs in `essential` mode: a failed dump fails that source's snapshot, so no
  inconsistent dump is shipped. Each source snapshots in its own run, so the failure does
  not suppress the others.
