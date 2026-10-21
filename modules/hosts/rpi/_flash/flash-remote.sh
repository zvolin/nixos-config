#!/usr/bin/env bash
# Runs on the Steam Deck. Two modes:
#   flash-remote.sh detect                 # list flashable disks (no root needed)
#   sudo flash-remote.sh flash DEVICE DIR  # write image + plant key
#
# Plain bash on purpose — it is scp'd and executed by the Deck's own bash, so it
# must carry no /nix/store shebang the Deck cannot resolve.
#
# The authoritative safety rule lives here, shared by both modes: never touch a
# disk that backs the running system. The Deck's built-in microSD slot reports
# RM=0 (non-removable) just like the NVMe, so "removable" tells us nothing —
# "does it back the OS?" is the only reliable question.
set -euo pipefail

# Disk names (e.g. "nvme0n1") that back the Deck's live system — off limits.
protected_disks() {
  local mp src disk
  for mp in / /nix /home /var /efi /boot; do
    src=$(findmnt -nro SOURCE --target "$mp" 2>/dev/null | head -n1) || true
    [[ -n "${src:-}" ]] || continue
    src=${src%%\[*}                                 # strip btrfs [subvol] suffix
    disk=$(lsblk -no PKNAME "$src" 2>/dev/null | head -n1)
    [[ -n "$disk" ]] || disk=$(lsblk -no NAME "$src" 2>/dev/null | head -n1)
    [[ -n "$disk" ]] && echo "$disk"
  done | sort -u
}

disk_name_of() {                                     # /dev/xxx -> owning disk name
  local pk
  pk=$(lsblk -no PKNAME "$1" 2>/dev/null | head -n1) # set when a partition is passed
  [[ -n "$pk" ]] && { echo "$pk"; return; }
  basename "$1"
}

cmd="${1:?usage: flash-remote.sh detect | flash DEVICE WORKDIR}"

case "$cmd" in
  detect)
    mapfile -t prot < <(protected_disks)
    # Fail closed: if we can't tell which disks run the OS, offer none rather
    # than risk listing the system disk as flashable.
    (( ${#prot[@]} )) || { echo "flash-remote: could not determine the Deck's system disks" >&2; exit 1; }
    lsblk -dpno NAME,TYPE,SIZE,MODEL | while read -r name type size model; do
      [[ "$type" == "disk" ]] || continue
      base=$(basename "$name")
      case "$base" in zram*|loop*|ram*|sr*) continue ;; esac
      for p in "${prot[@]}"; do [[ "$base" == "$p" ]] && continue 2; done
      printf '%s\t%s\t%s\n' "$name" "$size" "${model:-?}"
    done
    ;;

  flash)
    device="${2:?usage: flash-remote.sh flash DEVICE WORKDIR}"
    workdir="${3:?usage: flash-remote.sh flash DEVICE WORKDIR}"
    img="$workdir/image.img.zst"
    key="$workdir/host_key"
    pub="$workdir/host_key.pub"
    mnt="$workdir/mnt"
    label="NIXOS_SD"

    [[ -b "$device" ]] || { echo "not a block device: $device" >&2; exit 1; }
    # Authoritative guard: refuse any disk backing the running system, whatever
    # the caller passed. Fail closed if the system-disk set can't be determined.
    mapfile -t prot < <(protected_disks)
    (( ${#prot[@]} )) || { echo "REFUSING: could not determine the Deck's system disks" >&2; exit 1; }
    target_disk=$(disk_name_of "$device")
    for p in "${prot[@]}"; do
      [[ "$target_disk" == "$p" ]] && { echo "REFUSING: $device backs the Deck's running system ($p)" >&2; exit 1; }
    done
    [[ -f "$img" ]] || { echo "image missing: $img" >&2; exit 1; }
    [[ -f "$key" && -f "$pub" ]] || { echo "host key missing in $workdir" >&2; exit 1; }

    # dd fails on a busy device; release every child partition first (the card
    # may carry an auto-mounted NIXOS_SD from a previous flash).
    while read -r part; do
      [[ -n "$part" ]] || continue
      umount "/dev/$part" 2>/dev/null || true
    done < <(lsblk -lno NAME "$device" | tail -n +2)

    echo ">> Writing image to $device"
    zstd -dc "$img" | dd of="$device" bs=4M status=progress conv=fsync
    sync
    partprobe "$device" 2>/dev/null || true

    # The NIXOS_SD by-label symlink appears only after udev processes the fresh
    # table; poll rather than race it.
    for _ in $(seq 1 15); do
      [[ -e "/dev/disk/by-label/$label" ]] && break
      partprobe "$device" 2>/dev/null || true
      sleep 1
    done
    [[ -e "/dev/disk/by-label/$label" ]] || { echo "label $label did not appear after flashing" >&2; exit 1; }

    echo ">> Planting host key on $label"
    umount "/dev/disk/by-label/$label" 2>/dev/null || true
    mkdir -p "$mnt"
    mount "/dev/disk/by-label/$label" "$mnt"
    mkdir -p "$mnt/etc/ssh"
    install -m 600 -o 0 -g 0 "$key" "$mnt/etc/ssh/ssh_host_ed25519_key"
    install -m 644 -o 0 -g 0 "$pub" "$mnt/etc/ssh/ssh_host_ed25519_key.pub"
    sync
    umount "$mnt"
    echo ">> Card flashed and host key planted."
    ;;

  *)
    echo "unknown command: $cmd" >&2
    exit 1
    ;;
esac
