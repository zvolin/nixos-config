# ZFS & RAID concepts (M1 storage foundation)

A concepts primer for the `nas` storage pool. It explains the ideas M1 is built on so a
future reader can re-orient without re-deriving them. This is not the as-built config;
for that, read the `nas` ZFS aspects and the pool-creation runbook. The concrete numbers
below (disk count, recordsizes, caps) are M1's choices, shown to make each concept
concrete.

## Why ZFS (and why not btrfs for the array)

ZFS is one integrated layer that does three jobs other stacks split apart: the
**filesystem**, the **volume manager** (it owns the raw disks directly, with no
`mdadm`/LVM underneath), and the **RAID** engine. Because one layer sees the disks, the
checksums, and the redundancy together, it can both detect corruption and repair it from
parity. A split stack cannot, because the filesystem never learns which mirror copy was
wrong.

The laptop (`mbp-m2`) runs btrfs single-disk, which is fine. The `nas` array does not,
because btrfs parity RAID (raid5/6) has the **write hole**: an interrupted stripe write
can corrupt data that was already committed. Upstream still flags it unstable. ZFS RAIDZ
closes that hole by design, since every write is a full-stripe copy-on-write (below).

## The storage hierarchy

```
disk  →  vdev  →  pool  →  dataset
```

- **disk**: a whole physical drive, addressed by stable id (`/dev/disk/by-id/`, prefer
  `wwn-*`), never `/dev/sdX`, which renumbers across reboots and reslots.
- **vdev** (virtual device): a redundancy group built from disks. Redundancy lives here.
  A RAIDZ1 vdev tolerates one disk loss. The `nas` pool is one four-disk RAIDZ1 vdev.
- **pool** (`zpool`): one or more vdevs striped together; the unit you create, import,
  export, and scrub. Losing any one vdev loses the whole pool, so the vdev's redundancy
  is what protects it.
- **dataset**: a named filesystem carved from the pool. Datasets share the pool's free
  space but each has its own properties (recordsize, compression, encryption, snapshots).
  They are the unit of policy, not partitions of fixed size.

The pool name `tank` is pure convention (the ZFS docs' running example) and carries no
meaning.

## RAIDZ1 and the resilver window

RAIDZ1 is N+1 single parity: four disks give three disks of data plus one of parity, and
the pool survives one disk failure. When a failed disk is replaced, ZFS **resilvers**: it
rebuilds the missing disk from the survivors. During that rebuild the pool runs at zero
redundancy, so a second disk failing (or an unrecoverable read error on a survivor)
before the resilver finishes loses the pool. Large drives make this window long. That
exposure is a core reason the design requires an off-site backup and does not treat the
pool's parity as a substitute for one.

## Copy-on-write (COW)

ZFS never overwrites live data in place. It writes new blocks, then atomically flips
pointers to them. Three things follow:

- **Crash-consistency without `fsck`.** An interrupted write leaves the old data intact.
  This is also what closes the parity write hole.
- **Cheap snapshots.** A snapshot just pins the old block pointers, so it costs nothing up
  front and grows only as live data diverges from it.
- **The fill derate.** A COW pool needs free space to write into and fragments as it
  fills, so it is kept under about 80% full. On `nas` that turns ~21.8 TiB raw-usable into
  ~17.4 TiB working space. Capacity is planned against the working figure.

## Checksums, scrub, and self-healing

Every block carries a **checksum**. On read, ZFS verifies it; if it fails and the vdev
has redundancy, ZFS reconstructs the good block from parity, returns it, and rewrites the
bad copy. That is **self-healing** of silent bit rot. A **scrub** (`zpool scrub`, run
monthly) walks every block proactively, so rot is caught and healed before the data is
needed rather than discovered during a resilver when redundancy is already gone.

A scrub is not a SMART test. A scrub checks **data integrity**: are the bytes still
correct, per ZFS's own checksums. A SMART self-test (`smartd`) checks **hardware
health**: is the drive itself failing, by reallocated sectors and read errors. Both run,
they answer different questions, and neither replaces the other.

## Datasets: recordsize, compression, hygiene props

A parent dataset sets universal **hygiene properties** that children inherit:
`compression=lz4`, `atime=off`, `xattr=sa`, `acltype=posixacl`, `dnodesize=auto`.
Compression is on everywhere; lz4 is near-free and skips incompressible data.

`recordsize` is the one knob tuned per workload. It is the maximum logical block size,
matched to how the data is read and written:

| Workload            | recordsize | why                                    |
| ------------------- | ---------- | -------------------------------------- |
| media library       | `128k`     | large files, but torrents random-read  |
| Immich library      | `1M`       | write-once, read-sequential photos     |
| Postgres            | `8k`       | matches the DB page; `zstd`, HDD-tuned |
| scratch / transient | `16k`      | genuine throwaway only                 |

A mismatched recordsize wastes IO: an 8k DB page read from a 1M record pulls a full 1M.
Related datasets that must hardlink across each other stay in one dataset, because a
hardlink cannot cross a dataset boundary. That is why downloads and the library share a
single media dataset.

## Snapshots, sanoid, and why a snapshot is not a backup

A **snapshot** is a frozen, read-only view of a dataset at a point in time: instant,
space-cheap (COW), and good for undoing a mistake or taking a consistent read. **sanoid**
automates taking and pruning snapshots on a schedule, with retention tiered by how
precious the data is. Authoritative datasets keep long local history, media keeps a short
rollback window, and scratch keeps none.

A snapshot is not a backup. It lives on the **same pool** as the data it protects, so it
dies with the pool: disk fire, controller fault, `zpool destroy`, or ransomware with pool
access. It defends against mistakes, not against losing the pool. A real backup is a
separate copy, on separate hardware, in a separate place. That is a different layer
(off-site, out of M1's scope).

## Native encryption

ZFS encrypts at rest, inside the pool. Data and metadata are ciphertext on disk, while
filenames, properties, and the tree structure stay protected only as long as the key is
not loaded. The key ideas:

- **Key-to-mount.** An encrypted dataset's data is unreadable until its key is loaded
  (`zfs load-key`) and the dataset mounted. Loading the key is the gate.
- **encryptionroot and inheritance.** Encryption is set on a dataset and inherited by its
  children, which share that root's key. M1 sets one whole-pool encryptionroot so every
  child, media included, is covered; otherwise cleartext filenames would leak.
- **`key-loss = data-loss`.** There is no recovery path without the key. So the key must
  be escrowed out-of-band and its recovery proven before any real data lands. A lost key
  is indistinguishable from a wiped pool.

Native encryption also enables raw replication (`zfs send -w`): the backup target
receives ciphertext it can never decrypt. That is the enabling primitive for a future
pull-receiver backup.

## ARC and the monitoring kit

**ARC** (Adaptive Replacement Cache) is ZFS's in-RAM read cache. It is adaptive and fast,
and it will use all the RAM it is allowed, so on a box sharing RAM with services it is
capped (16 GB on `nas`, plus a `zfs_arc_sys_free` floor so the system never starves);
raise it later under real measured load. ARC is a cache, so losing it costs only speed,
never data.

Around it sits the health kit:

- **ZED** (ZFS Event Daemon) fires on pool events, such as a disk dropping or a scrub
  finding errors. The degrade alarm hangs off this.
- **smartd** runs scheduled SMART self-tests for drive hardware health.
- **`zpool status` cron backstop**: a periodic grep, because ZED can miss a degrade event
  and a silently-degraded pool is the exact thing M1 must never allow.
- **httm** is a friendly browser over snapshots for finding and restoring past versions
  of a file.
