#!/usr/bin/env bash
# Run this INSIDE the NixOS kexec installer (or a NixOS live USB), after cloning
# this repo. You are already root there, so no sudo needed.
#
# Same leashed-disko safety as install.sh: formats ONLY the two NixOS partitions
# you created in the space freed by shrinking Windows. Windows' own partitions are
# never named and stay intact.
#
# DIFFERENCE vs install.sh: this also seeds the lanzaboote Secure Boot keys into
# the target before nixos-install, so the signed bootloader installs on the FIRST
# pass (halo runs lanzaboote from day one). After first boot you still enroll the
# keys in firmware — see README's "Secure Boot (lanzaboote)" procedure.
set -euo pipefail

FLAKE_ATTR="halo"
# !!! FILL THESE IN after creating the partitions (see step 0 below). They MUST
# match the PARTUUIDs you put in hosts/halo/disko.nix.
ESP_UUID="REPLACE-WITH-NEW-ESP-PARTUUID"   # NixOS ESP  -> /boot (vfat)
ROOT_UUID="REPLACE-WITH-NEW-ROOT-PARTUUID" # NixOS root -> /     (btrfs)

cd "$(cd "$(dirname "$0")" && pwd)"

# --- Step 0 reminder: create the two empty partitions in the freed space ------
# In the freed (unallocated) space after shrinking Windows, create:
#   - a ~1 GiB partition (will become the NixOS ESP)  -> note its PARTUUID
#   - a large partition for the rest (NixOS btrfs root) -> note its PARTUUID
# e.g. with `cgdisk /dev/nvme0n1` (type ef00 for the ESP, 8300 for root), then
#   lsblk -o NAME,SIZE,FSTYPE,PARTUUID,PARTLABEL /dev/nvme0n1
# Put those two PARTUUIDs into BOTH this script (above) and hosts/halo/disko.nix.

echo "==> Disk layout:"
lsblk -o NAME,SIZE,FSTYPE,PARTLABEL,LABEL,PARTUUID
echo
echo "This will ERASE and format ONLY these two partitions:"
echo "  ESP  ($ESP_UUID)  -> /boot (vfat)"
echo "  root ($ROOT_UUID)  -> /     (btrfs)"
echo "Windows partitions are never named and stay intact."
echo
echo "Sanity check — these symlinks MUST point at the NixOS partitions you made:"
ls -l "/dev/disk/by-partuuid/$ESP_UUID" "/dev/disk/by-partuuid/$ROOT_UUID"
echo
read -rp "Type ERASE to proceed: " confirm
[ "$confirm" = "ERASE" ] || { echo "Aborted."; exit 1; }

echo "==> [1/4] Partitioning + formatting with disko (Windows untouched)..."
nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
  --mode destroy,format,mount --flake ".#${FLAKE_ATTR}"

echo "==> [2/4] Capturing this machine's hardware profile..."
nixos-generate-config --no-filesystems --root /mnt --show-hardware-config \
  > hosts/halo/hardware-configuration.nix
git add -A   # flake evaluation only sees git-tracked files

echo "==> [3/4] Seeding Secure Boot keys so lanzaboote signs on first install..."
# Create the sbctl key bundle and place it at the target's pkiBundle path
# (/var/lib/sbctl on the installed system == /mnt/var/lib/sbctl now). nixpkgs
# patches sbctl's default keydir to /var/lib/sbctl, matching boot.lanzaboote.
nix --experimental-features "nix-command flakes" run nixpkgs#sbctl -- create-keys
mkdir -p /mnt/var/lib
cp -a /var/lib/sbctl /mnt/var/lib/sbctl

echo "==> [4/4] Installing NixOS (lanzaboote signs the bootloader)..."
# If lanzaboote's bootloader step ever fails here, fall back to a plain
# systemd-boot first install, then enable lanzaboote after first boot:
#   nixos-install --flake ".#${FLAKE_ATTR}" \
#     --option ... (or temporarily set boot.lanzaboote.enable=false)
nixos-install --flake ".#${FLAKE_ATTR}"

echo
echo "==> Set a password for your user 'joshjob42':"
nixos-enter --root /mnt -c 'passwd joshjob42'

echo
echo "Done. Run:  reboot"
echo "Next: enroll Secure Boot keys in firmware (Custom mode -> Setup Mode ->"
echo "  sudo sbctl enroll-keys --microsoft -> reboot -> enable Secure Boot)."
echo "Then bootstrap the full private config (gh auth login; clone; nrs)."
