#!/usr/bin/env bash
# ==============================================================================
# Competitive Programming Lab Installation Script
# Usage: Run from NixOS Live USB
#   sudo ./scripts/install-lab.sh [/dev/sda or /dev/nvme0n1]
# ==============================================================================
set -euo pipefail

TARGET_DISK="${1:-/dev/sda}"
FLAKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== University Lab NixOS Installation ==="
echo "Target disk: $TARGET_DISK"
echo "Flake root : $FLAKE_DIR"
echo ""
read -rp "WARNING: All data on $TARGET_DISK will be erased. Proceed? [y/N]: " confirm
if [[ "$confirm" != [yY] && "$confirm" != [yY][eE][sS] ]]; then
  echo "Installation aborted."
  exit 1
fi

echo "[1/4] Running declarative disk partitioning with Disko..."
sudo nix --experimental-features 'nix-command flakes' run github:nix-community/disko -- \
  --mode disko \
  --arg device "\"$TARGET_DISK\"" \
  "$FLAKE_DIR/hosts/lab-pc/disko.nix"

echo "[2/4] Generating machine-specific hardware configuration..."
sudo nixos-generate-config --no-filesystems --root /mnt

# If the generated hardware-configuration differs, copy it over
if [ -f /mnt/etc/nixos/hardware-configuration.nix ]; then
  echo "Updating hosts/lab-pc/hardware-configuration.nix with detected hardware..."
  cp /mnt/etc/nixos/hardware-configuration.nix "$FLAKE_DIR/hosts/lab-pc/hardware-configuration.nix"
fi

echo "[3/4] Installing NixOS with contest configuration..."
sudo nixos-install --flake "$FLAKE_DIR#lab-pc" --no-root-password

echo "[4/4] Setting initial root and admin passwords..."
echo "Setting root password:"
sudo nixos-enter --root /mnt -c 'passwd root' || true
echo "Setting admin password:"
sudo nixos-enter --root /mnt -c 'passwd admin' || true

echo "=========================================================="
echo "Installation complete! You can now reboot the machine:"
echo "  sudo reboot"
echo "=========================================================="

