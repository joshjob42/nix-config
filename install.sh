#!/usr/bin/env bash
# Run this INSIDE the NixOS kexec installer, after cloning this repo.
# (In the installer you are already root, so no sudo needed.)
set -euo pipefail

FLAKE_ATTR="geekbook14"
ESP_UUID="1814dcf3-2e06-4b66-883d-f3c0b8e56c31"   # nvme0n1p7 -> /boot
ROOT_UUID="d35b7008-1be4-43e0-a165-67683ecac70d"  # nvme0n1p6 -> /  (btrfs)

cd "$(cd "$(dirname "$0")" && pwd)"

echo "==> Disk layout (nvme0n1):"
lsblk -o NAME,SIZE,FSTYPE,PARTLABEL,LABEL /dev/nvme0n1
echo
echo "This will ERASE and format ONLY these two partitions:"
echo "  p7 ESP   ($ESP_UUID)  -> /boot (vfat)"
echo "  p6 root  ($ROOT_UUID)  -> /     (btrfs)"
echo "Windows partitions (p1/p2/p3/p5) are never named and stay intact."
echo
echo "Sanity check — these symlinks MUST point at nvme0n1p7 and nvme0n1p6:"
ls -l "/dev/disk/by-partuuid/$ESP_UUID" "/dev/disk/by-partuuid/$ROOT_UUID"
echo
read -rp "Type ERASE to proceed: " confirm
[ "$confirm" = "ERASE" ] || { echo "Aborted."; exit 1; }

echo "==> [1/3] Partitioning + formatting p6/p7 with disko (Windows untouched)..."
nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
  --mode destroy,format,mount --flake ".#${FLAKE_ATTR}"

echo "==> [2/3] Capturing this machine's hardware profile..."
nixos-generate-config --no-filesystems --root /mnt --show-hardware-config \
  > hosts/geekbook14/hardware-configuration.nix
git add -A   # flake evaluation only sees git-tracked files

echo "==> [3/3] Installing NixOS (sets the root password at the end)..."
nixos-install --flake ".#${FLAKE_ATTR}"

echo
echo "==> Set a password for your user 'joshjob42':"
nixos-enter --root /mnt -c 'passwd joshjob42'

echo
echo "Done. Run:  reboot"
echo "At the boot menu you'll see NixOS and Windows. No USB to remove."
