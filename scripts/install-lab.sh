#!/usr/bin/env bash
# ==============================================================================
# Competitive Programming Lab Installation / Switch Script
#
# Automatically detects whether it is running on:
#   1. A Live USB ISO installer:
#      - Wipes & formats selected target disk with Disko
#      - Applies Disko partitions (EFI + ext4 + RAM-based swap)
#      - Runs nixos-install
#   2. An already installed NixOS system:
#      - DOES NOT modify or format any disks
#      - Disables Disko (disko.enableConfig = false)
#      - Preserves existing disk layout from /etc/nixos/hardware-configuration.nix
#      - Runs nixos-rebuild switch
#
# Manual override options:
#   ./scripts/install-lab.sh --live [/dev/sda or /dev/nvme0n1]
#   ./scripts/install-lab.sh --installed
# ==============================================================================
set -euo pipefail

FLAKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$FLAKE_DIR/hosts/lab-pc/configuration.nix"
HW_CONFIG_DEST="$FLAKE_DIR/hosts/lab-pc/hardware-configuration.nix"

# Function to detect if running on a live USB installer
is_live_installer() {
  # 1. Live ISO filesystem signatures:
  if [ -d /nix/.ro-store ] || [ -f /iso/nix-store.squashfs ]; then
    return 0
  fi
  if readlink -f /run/current-system 2>/dev/null | grep -qiE "installer|installation-cd"; then
    return 0
  fi
  if grep -qiE "nixos-installer|installation-cd" /proc/cmdline 2>/dev/null; then
    return 0
  fi
  # 2. If /etc/nixos/hardware-configuration.nix is missing, this is a live installer session
  if [ ! -f /etc/nixos/hardware-configuration.nix ]; then
    return 0
  fi
  # Otherwise, this is a running installed NixOS host
  return 1
}

# Parse manual flags
MODE=""
TARGET_DISK=""
SWAP_SIZE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --live|--fresh)
      MODE="live"
      shift
      if [[ $# -gt 0 && "$1" != --* ]]; then
        TARGET_DISK="$1"
        shift
      fi
      ;;
    --swap)
      shift
      if [[ $# -gt 0 ]]; then
        SWAP_SIZE="$1"
        shift
      fi
      ;;
    --installed|--switch)
      MODE="installed"
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --live [DEVICE]    Force Live USB install mode (formats drive with Disko, e.g. /dev/sda)"
      echo "  --swap [SIZE]      Specify swap size (e.g. 2G, 4G, 8G; calculated from RAM by default)"
      echo "  --installed        Force installed system mode (preserves existing disk config)"
      echo "  -h, --help         Show this help message"
      echo ""
      echo "Without flags, the script auto-detects the environment."
      exit 0
      ;;
    *)
      if [ -z "$TARGET_DISK" ] && [[ "$1" == /dev/* ]]; then
        TARGET_DISK="$1"
      fi
      shift
      ;;
  esac
done

# Auto-detect environment if not explicitly set by flag
if [ -z "$MODE" ]; then
  if is_live_installer; then
    MODE="live"
  else
    MODE="installed"
  fi
fi

echo "=========================================================="
echo "   NixOS Competitive Programming Lab Setup"
echo "=========================================================="
echo "Flake root: $FLAKE_DIR"

# ==============================================================================
# MODE 1: Fresh Installation from Live USB (Disko Partitioning)
# ==============================================================================
if [ "$MODE" = "live" ]; then
  echo "Detected Environment: Live USB Installer"
  echo "Mode                : Fresh Install (Disko Partitioning + nixos-install)"
  echo "----------------------------------------------------------"
  echo "[NOTICE]: Disko partition manager WILL be applied to format the target disk."

  if [ -z "$TARGET_DISK" ]; then
    echo ""
    echo "Available storage disks:"
    lsblk -d -p -n -l -o NAME,SIZE,TYPE,MODEL | grep -E "disk" || true
    echo ""
    read -rp "Enter target disk to install NixOS onto (e.g. /dev/sda or /dev/nvme0n1): " TARGET_DISK
  fi

  if [ -z "$TARGET_DISK" ] || [ ! -b "$TARGET_DISK" ]; then
    echo "Error: Invalid disk device '$TARGET_DISK'" >&2
    exit 1
  fi

  echo ""
  echo "WARNING: ALL DATA ON $TARGET_DISK WILL BE COMPLETELY ERASED!"
  read -rp "Are you sure you want to proceed with fresh installation? [y/N]: " confirm
  if [[ "$confirm" != [yY] && "$confirm" != [yY][eE][sS] ]]; then
    echo "Installation cancelled."
    exit 1
  fi

  # Determine swap size based on physical RAM (no hibernation)
  if [ -z "$SWAP_SIZE" ]; then
    TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "8388608")
    TOTAL_RAM_GB=$(( (TOTAL_RAM_KB + 1048575) / 1048576 ))

    # Sizing for paging without hibernation:
    # <= 2GB RAM: swap = RAM size (e.g. 2GB)
    # 2GB - 16GB: swap = 4GB (ample for paging without wasting disk space)
    # > 16GB RAM: swap = 8GB
    if [ "$TOTAL_RAM_GB" -le 2 ]; then
      CALC_SWAP="${TOTAL_RAM_GB}G"
    elif [ "$TOTAL_RAM_GB" -le 16 ]; then
      CALC_SWAP="4G"
    else
      CALC_SWAP="8G"
    fi

    echo ""
    echo "Hardware RAM detected : ${TOTAL_RAM_GB} GB"
    echo "Recommended swap size : ${CALC_SWAP} (paging only, no hibernation)"
    read -rp "Enter swap size to allocate [$CALC_SWAP]: " USER_SWAP
    SWAP_SIZE="${USER_SWAP:-$CALC_SWAP}"
  fi

  echo "Allocating swap partition: $SWAP_SIZE"

  # Enable Disko filesystem generation for fresh install
  sed -i 's/disko\.enableConfig = .*/disko.enableConfig = true;/' "$CONFIG_FILE"
  # Update default swap size in disko.nix
  sed -i "s/swapSize ? \".*\"/swapSize ? \"$SWAP_SIZE\"/" "$FLAKE_DIR/hosts/lab-pc/disko.nix"

  echo ""
  echo "[1/5] Partitioning and formatting disk with Disko (Swap: $SWAP_SIZE)..."
  sudo nix --experimental-features 'nix-command flakes' run github:nix-community/disko -- \
    --mode disko \
    --arg device "\"$TARGET_DISK\"" \
    --arg swapSize "\"$SWAP_SIZE\"" \
    "$FLAKE_DIR/hosts/lab-pc/disko.nix"

  echo "[2/5] Generating hardware configuration from detected hardware..."
  sudo nixos-generate-config --no-filesystems --root /mnt

  echo "[3/5] Updating flake with detected hardware..."
  cp /mnt/etc/nixos/hardware-configuration.nix "$HW_CONFIG_DEST"
  (cd "$FLAKE_DIR" && git add -f "$HW_CONFIG_DEST" "$CONFIG_FILE" "$FLAKE_DIR/hosts/lab-pc/disko.nix")

  echo "[4/6] Installing NixOS contest system closure..."
  sudo nixos-install --flake "$FLAKE_DIR#lab-pc" --no-root-password

  echo "[5/6] Setting initial user passwords..."
  echo "Set root password:"
  sudo nixos-enter --root /mnt -c 'passwd root' || true
  echo "Set admin password:"
  sudo nixos-enter --root /mnt -c 'passwd admin' || true

  echo "[6/6] Copying nixos-cp repository to /home/admin/nixos-cp..."
  sudo mkdir -p /mnt/home/admin
  sudo cp -a "$FLAKE_DIR" /mnt/home/admin/nixos-cp
  sudo nixos-enter --root /mnt -c 'chown -R admin:users /home/admin/nixos-cp && chmod 700 /home/admin' || true

  echo "=========================================================="
  echo "Fresh installation complete! Remove the USB and reboot:"
  echo "  sudo reboot"
  echo ""
  echo "Post-reboot notes:"
  echo "  - Contest environment boots automatically into 'contestant' user."
  echo "  - Administration flake is ready at: /home/admin/nixos-cp"
  echo "=========================================================="

# ==============================================================================
# MODE 2: Already Installed NixOS System (Preserves Existing Disks)
# ==============================================================================
else
  echo "Detected Environment: Already Installed NixOS System"
  echo "Mode                : In-Place Switch (Preserves existing disk configuration)"
  echo "----------------------------------------------------------"
  echo "[SAFETY ASSURANCE]:"
  echo "  - Your existing disk partitions and filesystems will NOT be modified or formatted."
  echo "  - Disko partition manager is completely DISABLED (disko.enableConfig = false)."
  echo "  - Preserving all mountpoints and UUIDs from /etc/nixos/hardware-configuration.nix."
  echo "----------------------------------------------------------"

  if [ ! -f /etc/nixos/hardware-configuration.nix ]; then
    echo "Error: /etc/nixos/hardware-configuration.nix not found." >&2
    echo "Cannot determine the running system's disk mounts." >&2
    exit 1
  fi

  echo "Existing mountpoints to be preserved:"
  grep -E 'fileSystems\."[^"]+"' /etc/nixos/hardware-configuration.nix | sed 's/^[ \t]*/  - /' || true
  if grep -q "swapDevices" /etc/nixos/hardware-configuration.nix; then
    echo "  - swapDevices (preserved)"
  fi
  echo ""

  echo "This will apply the competitive programming contest configuration"
  echo "(KDE Plasma 6, VS Code, compilers, CP tools, contest user) onto this machine."
  read -rp "Proceed with applying configuration to this system? [Y/n]: " confirm
  if [[ "$confirm" == [nN] || "$confirm" == [nN][oO] ]]; then
    echo "Aborted."
    exit 1
  fi

  echo ""
  echo "[1/5] Copying existing hardware & filesystem configuration..."
  cp /etc/nixos/hardware-configuration.nix "$HW_CONFIG_DEST"

  echo "[2/5] Ensuring Disko partition manager is disabled..."
  # Explicitly disable Disko so existing partitions in hardware-configuration.nix are used as-is
  sed -i 's/disko\.enableConfig = .*/disko.enableConfig = false;/' "$CONFIG_FILE"
  (cd "$FLAKE_DIR" && git add -f "$HW_CONFIG_DEST" "$CONFIG_FILE")

  echo "[3/5] Testing configuration before activating..."
  sudo nixos-rebuild test --flake "$FLAKE_DIR#lab-pc"

  echo "[4/5] Activating and registering default bootloader generation..."
  sudo nixos-rebuild switch --flake "$FLAKE_DIR#lab-pc"

  echo "[5/5] Ensuring nixos-cp repository is available in /home/admin/nixos-cp..."
  if [ "$FLAKE_DIR" != "/home/admin/nixos-cp" ]; then
    sudo mkdir -p /home/admin
    sudo cp -a "$FLAKE_DIR" /home/admin/nixos-cp
    sudo chown -R admin:users /home/admin/nixos-cp
    sudo chmod 700 /home/admin
    echo "Repository successfully copied to /home/admin/nixos-cp."
  else
    echo "Repository is already located at /home/admin/nixos-cp."
  fi

  echo "=========================================================="
  echo "Configuration successfully applied!"
  echo ""
  echo "Summary:"
  echo "  - Existing disk partitions & filesystems preserved untouched."
  echo "  - Desktop Environment: KDE Plasma 6 (SDDM)"
  echo "  - Contestant account : 'contestant' (Auto-login enabled)"
  echo "  - Admin account      : 'admin' (Wheel/sudo privileges)"
  echo "  - Admin repository   : Available at /home/admin/nixos-cp"
  echo "  - Tools & Compilers  : GCC, Clang, Python, Java 21, Rust, Go, VS Code, Code::Blocks"
  echo ""
  echo "You can now log out or restart SDDM to enter the contest environment:"
  echo "  sudo systemctl restart display-manager"
  echo "=========================================================="
fi
