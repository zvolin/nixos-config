# flash-rpi — build the rpi sd-image on this (aarch64) host and flash it to an SD
# card inserted in the Steam Deck over SSH, planting the host key before first
# boot. Runs on the Mac; drives the Deck with ssh/scp. $FLASH_REMOTE_SCRIPT is
# the Deck-side flasher, injected by the Nix wrapper. See
# docs/runbooks/rpi-install.md.

HOST="deck@steamdeck"
KEY="./host_rpi_ed25519_key"
DEVICE=""
FLAKE="."
DRYRUN=0

usage() {
  cat >&2 <<EOF
Usage: flash-rpi [options]
  --host USER@HOST   Steam Deck SSH target (default: deck@steamdeck)
  --key PATH         rpi ed25519 host private key (default: ./host_rpi_ed25519_key)
  --device /dev/sdX  SD card device on the Deck (default: auto-detect)
  --flake REF        flake ref to build rpi from (default: .)
  --dry-run          build + detect + show plan, write nothing to the card
  -h, --help         this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="$2"; shift 2 ;;
    --key) KEY="$2"; shift 2 ;;
    --device) DEVICE="$2"; shift 2 ;;
    --flake) FLAKE="$2"; shift 2 ;;
    --dry-run) DRYRUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

die() { echo "flash-rpi: $*" >&2; exit 1; }

# --- preflight: host key present and not readable by group/other ----------
[[ -f "$KEY" ]] || die "host key not found: $KEY (generate it per rpi-install.md §2)"
[[ -f "$KEY.pub" ]] || die "public key not found: $KEY.pub"
perms=$(stat -c '%a' "$KEY")
if (( 8#$perms & 8#77 )); then
  die "host key $KEY is group/other-readable ($perms); run: chmod 600 $KEY"
fi
grep -q 'PRIVATE KEY' "$KEY" || die "$KEY does not look like a private key"

# --- preflight: Deck reachable and has the tools we need ------------------
echo "flash-rpi: checking $HOST ..."
ssh "$HOST" 'for t in zstd lsblk dd partprobe install findmnt; do command -v "$t" >/dev/null || { echo "missing on deck: $t" >&2; exit 1; }; done' \
  || die "Deck preflight failed (unreachable, or a tool above is missing)"

# --- build the sd-image natively ------------------------------------------
echo "flash-rpi: building sd-image (binary cache used where possible) ..."
out=$(nix build --no-link --print-out-paths "$FLAKE#nixosConfigurations.rpi.config.system.build.sdImage") \
  || die "nix build failed"
shopt -s nullglob
imgs=("$out"/sd-image/*.img.zst)
shopt -u nullglob
(( ${#imgs[@]} == 1 )) || die "expected one .img.zst under $out/sd-image, found ${#imgs[@]}"
img="${imgs[0]}"
echo "flash-rpi: built $img"

# --- stage the Deck-side flasher (used for both detect and flash) ----------
remdir=$(ssh "$HOST" 'mktemp -d /tmp/flash-rpi.XXXXXX') || die "mktemp on Deck failed"
# Always wipe the temp dir — it ends up holding the private host key — on any exit.
# shellcheck disable=SC2029  # expand $remdir locally into the remote command
cleanup() { ssh "$HOST" "rm -rf -- '$remdir'" >/dev/null 2>&1 || true; }
trap cleanup EXIT
scp -q "$FLASH_REMOTE_SCRIPT" "$HOST:$remdir/flash-remote.sh" || die "scp flasher failed"

# --- choose the target device on the Deck ---------------------------------
# Candidates exclude the disks backing the Deck's running system, so a mistake
# here cannot wipe the Deck. The Deck decides what is protected (see the flasher).
if [[ -z "$DEVICE" ]]; then
  # shellcheck disable=SC2029  # expand $remdir locally into the remote command
  mapfile -t cands < <(ssh "$HOST" "bash '$remdir/flash-remote.sh' detect")
  (( ${#cands[@]} > 0 )) || die "no flashable disk on $HOST (only the system disk found) — is the SD card inserted?"
  if (( ${#cands[@]} > 1 )); then
    echo "Multiple candidate disks on $HOST:" >&2
    printf '  %s\n' "${cands[@]}" >&2
    die "pass the right one with --device /dev/sdX"
  fi
  DEVICE=${cands[0]%%$'\t'*}
  desc=${cands[0]}
else
  # shellcheck disable=SC2029  # expand $DEVICE locally into the remote command
  desc=$(ssh "$HOST" "lsblk -dpno NAME,SIZE,MODEL '$DEVICE'") || die "cannot stat $DEVICE on $HOST"
fi

echo
echo "About to ERASE this device on $HOST and flash the rpi image:"
printf '    %s\n' "$desc"
echo

if (( DRYRUN )); then
  echo "flash-rpi: --dry-run, stopping before any write to the card."
  echo "  would copy : $img -> $HOST"
  echo "  would flash: $DEVICE  (and plant the host key)"
  exit 0
fi

read -r -p "Type 'yes' to continue: " reply
[[ "$reply" == "yes" ]] || die "aborted"

# --- copy image + key to the Deck temp dir --------------------------------
echo "flash-rpi: copying image + host key to $HOST:$remdir ..."
scp -q "$img" "$HOST:$remdir/image.img.zst" || die "scp image failed"
scp -q "$KEY" "$HOST:$remdir/host_key" || die "scp key failed"
scp -q "$KEY.pub" "$HOST:$remdir/host_key.pub" || die "scp pubkey failed"

# --- flash + plant in one elevated session (sudo prompts via the tty) ------
echo "flash-rpi: flashing + planting (the Deck's sudo may prompt) ..."
# shellcheck disable=SC2029  # expand $remdir/$DEVICE locally into the remote command
ssh -t "$HOST" "sudo bash '$remdir/flash-remote.sh' flash '$DEVICE' '$remdir'" \
  || die "remote flash failed"

echo "flash-rpi: done. Eject the card and boot the Pi."
