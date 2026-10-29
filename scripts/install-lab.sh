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
#      - Generates fresh hardware & filesystem configuration from the running system
#      - Runs nixos-rebuild switch
#
# Manual override options:
#   ./scripts/install-lab.sh --live [/dev/sda or /dev/nvme0n1]
#   ./scripts/install-lab.sh --installed
# ==============================================================================
set -euo pipefail

# Ensure script is running as root upfront so user removal/switch does not break permissions
if [ "$(id -u)" -ne 0 ]; then
  echo "Administrator privileges are required to configure NixOS."
  exec sudo env "PATH=$PATH" bash "$0" "$@"
fi

# Configure git to allow working across directories without dubious ownership errors
git config --global --add safe.directory '*' 2>/dev/null || true

FLAKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$FLAKE_DIR/hosts/lab-pc/configuration.nix"
HW_CONFIG_DEST="$FLAKE_DIR/hosts/lab-pc/hardware-configuration.nix"

# Function to detect if running on a live USB installer
is_live_installer() {
  # 1. Live ISO filesystem signatures (read-only store or squashfs)
  if [ -d /nix/.ro-store ] || [ -f /iso/nix-store.squashfs ]; then
    return 0
  fi
  # 2. System profile indicates an installer/installation-cd
  if readlink -f /run/current-system 2>/dev/null | grep -qiE "installer|installation-cd"; then
    return 0
  fi
  # 3. Kernel command-line indicates an installer
  if grep -qiE "nixos-installer|installation-cd|live" /proc/cmdline 2>/dev/null; then
    return 0
  fi
  # 4. Hostname or booted user indicates standard NixOS live media
  if [ "$(hostname 2>/dev/null)" = "nixos" ] && [ "$(id -un 2>/dev/null || whoami)" = "nixos" ]; then
    return 0
  fi
  # Otherwise, this is a running installed NixOS host
  return 1
}

# Parse manual flags
MODE=""
TARGET_DISK=""
SWAP_SIZE=""
CHOSEN_USER=""
ADMIN_PASS=""

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
    --user|-u)
      shift
      if [[ $# -gt 0 ]]; then
        CHOSEN_USER="$1"
        shift
      fi
      ;;
    --admin-pass)
      shift
      if [[ $# -gt 0 ]]; then
        ADMIN_PASS="$1"
        shift
      fi
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --live [DEVICE]       Force Live USB install mode (formats drive with Disko, e.g. /dev/sda)"
      echo "  --swap [SIZE]         Specify swap size (e.g. 2G, 4G, 8G; calculated from RAM by default)"
      echo "  --installed           Force installed system mode (preserves existing disk config)"
      echo "  --user, -u [NAME]     Set contest participant username (prompts if omitted)"
      echo "  --admin-pass [PASS]   Set admin/sudo/root password (prompts securely if omitted)"
      echo "  -h, --help            Show this help message"
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

# ------------------------------------------------------------------------------
# User Account & Password Configuration
# ------------------------------------------------------------------------------
if [ -z "$CHOSEN_USER" ]; then
  echo ""
  echo "--- Contest User Configuration ---"
  while true; do
    read -rp "Enter username for contest participants (e.g. pc01, student, participant): " INPUT_USER
    INPUT_USER="$(echo "$INPUT_USER" | xargs | tr '[:upper:]' '[:lower:]')"
    if [ -z "$INPUT_USER" ]; then
      echo "Username cannot be empty. Please enter a valid username."
      continue
    fi
    if ! [[ "$INPUT_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
      echo "Invalid username '$INPUT_USER'. Must start with a lowercase letter and contain only letters, digits, '_' or '-'."
      continue
    fi
    if [[ "$INPUT_USER" =~ ^(admin|root|wheel|users|nixos|systemd|nobody)$ ]]; then
      echo "Username '$INPUT_USER' is reserved for system administration. Please choose another username."
      continue
    fi
    CHOSEN_USER="$INPUT_USER"
    break
  done
fi

if [ -z "$ADMIN_PASS" ]; then
  echo ""
  echo "--- Administrator Password ---"
  echo "Set the password for 'admin' (used for sudo commands) and 'root':"
  while true; do
    read -rsp "Enter admin/sudo password: " PASS1
    echo ""
    read -rsp "Confirm admin/sudo password: " PASS2
    echo ""
    if [ "$PASS1" != "$PASS2" ]; then
      echo "Passwords do not match. Please try again."
      continue
    fi
    if [ -z "$PASS1" ]; then
      echo "Password cannot be empty. Please try again."
      continue
    fi
    ADMIN_PASS="$PASS1"
    break
  done
fi

# Configure chosen participant user in configuration.nix
if grep -q "lab\.user = " "$CONFIG_FILE"; then
  sed -i "s/lab\.user = .*/lab.user = \"$CHOSEN_USER\";/" "$CONFIG_FILE"
else
  sed -i "s/}$/  lab.user = \"$CHOSEN_USER\";\n}/" "$CONFIG_FILE"
fi

# ==============================================================================
# MODE 1: Fresh Installation from Live USB (Disko Partitioning)
# ==============================================================================
if [ "$MODE" = "live" ]; then
  echo ""
  echo "Detected Environment: Live USB Installer"
  echo "Mode                : Fresh Install (Disko Partitioning + nixos-install)"
  echo "Participant Account : $CHOSEN_USER"
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
  echo "[1/6] Partitioning and formatting disk with Disko (Swap: $SWAP_SIZE)..."
  sudo nix --experimental-features 'nix-command flakes' run github:nix-community/disko -- \
    --mode disko \
    --arg device "\"$TARGET_DISK\"" \
    --arg swapSize "\"$SWAP_SIZE\"" \
    "$FLAKE_DIR/hosts/lab-pc/disko.nix"

  echo "[2/6] Generating hardware configuration from detected hardware..."
  sudo nixos-generate-config --no-filesystems --root /mnt

  echo "[3/6] Updating flake with detected hardware..."
  cp /mnt/etc/nixos/hardware-configuration.nix "$HW_CONFIG_DEST"
  (cd "$FLAKE_DIR" && git add -f hosts/lab-pc/hardware-configuration.nix hosts/lab-pc/configuration.nix hosts/lab-pc/disko.nix)

  echo "[4/6] Installing NixOS contest system closure..."
  sudo nixos-install --flake "$FLAKE_DIR#lab-pc" --no-root-password

  echo "[5/6] Setting same password for 'admin' and 'root' (sudo)..."
  echo "admin:$ADMIN_PASS" | sudo nixos-enter --root /mnt -c 'chpasswd'
  echo "root:$ADMIN_PASS" | sudo nixos-enter --root /mnt -c 'chpasswd'

  echo "[6/6] Copying nixos-cp repository to /home/admin/nixos-cp..."
  sudo mkdir -p /mnt/home/admin
  sudo cp -a "$FLAKE_DIR" /mnt/home/admin/nixos-cp
  sudo nixos-enter --root /mnt -c 'chown -R admin:users /home/admin/nixos-cp && chmod 700 /home/admin' || true
  sudo nixos-enter --root /mnt -c 'su - admin -c "git config --global user.name admin && git config --global user.email admin@example.com"' || true

  echo "=========================================================="
  echo "Fresh installation complete! Remove the USB and reboot:"
  echo "  sudo reboot"
  echo ""
  echo "Summary:"
  echo "  - Participant account : '$CHOSEN_USER' (Auto-login enabled)"
  echo "  - Admin account       : 'admin' (Wheel/sudo privileges, matching root password)"
  echo "  - Admin repository    : Ready at /home/admin/nixos-cp"
  echo "=========================================================="

# ==============================================================================
# MODE 2: Already Installed NixOS System (Preserves Existing Disks)
# ==============================================================================
else
  # Detect existing human user accounts (UID >= 1000 and < 30000) that are not admin and not CHOSEN_USER
  mapfile -t EXISTING_OTHER_USERS < <(awk -F: -v u="$CHOSEN_USER" '
    $3 >= 1000 && $3 < 30000 && $1 != "admin" && $1 != u { print $1 }
  ' /etc/passwd)

  echo ""
  echo "Detected Environment: Already Installed NixOS System"
  echo "Mode                : In-Place Switch (Preserves existing disk configuration)"
  echo "Participant Account : $CHOSEN_USER"
  echo "----------------------------------------------------------"
  echo "Generating fresh hardware configuration from the running system..."

  # Generate a fresh hardware configuration from the running machine every time
  nixos-generate-config --show-hardware-config > "$HW_CONFIG_DEST"

  # Explicitly disable Disko so the generated hardware-configuration.nix manages filesystems
  sed -i 's/disko\.enableConfig = .*/disko.enableConfig = false;/' "$CONFIG_FILE"
  (cd "$FLAKE_DIR" && git add -f hosts/lab-pc/hardware-configuration.nix hosts/lab-pc/configuration.nix)

  echo ""
  echo "[SAFETY & ACTIONS OVERVIEW]:"
  echo "  1. Your existing disk partitions and filesystems will NOT be modified."
  echo "  2. Participant account '$CHOSEN_USER' will be configured with auto-login."
  echo "  3. Same password will be set for 'admin' (sudo) and 'root'."
  if [ ${#EXISTING_OTHER_USERS[@]} -gt 0 ]; then
    echo "  4. [USER CLEANUP]: The following existing user accounts and their /home folders WILL BE DELETED:"
    for u in "${EXISTING_OTHER_USERS[@]}"; do
      echo "       * $u (/home/$u)"
    done
  else
    echo "  4. No other human user accounts found to delete."
  fi
  echo "  5. Flake repository will be copied to /home/admin/nixos-cp."
  echo "  6. System will be switched to contest configuration."
  echo "----------------------------------------------------------"

  echo "Active mountpoints detected and preserved:"
  grep -E 'fileSystems\."[^"]+"' "$HW_CONFIG_DEST" | sed 's/^[ \t]*/  - /' || true
  if grep -q "swapDevices" "$HW_CONFIG_DEST"; then
    echo "  - swapDevices (preserved)"
  fi
  echo ""

  read -rp "Proceed with applying configuration and user cleanup? [Y/n]: " confirm
  if [[ "$confirm" == [nN] || "$confirm" == [nN][oO] ]]; then
    echo "Aborted."
    exit 1
  fi

  echo ""
  echo "[1/4] Ensuring nixos-cp repository is available in /home/admin/nixos-cp..."
  git config --global --add safe.directory '*' 2>/dev/null || true
  git config --system --add safe.directory '*' 2>/dev/null || true

  if [ "$FLAKE_DIR" != "/home/admin/nixos-cp" ]; then
    mkdir -p /home/admin
    cp -a "$FLAKE_DIR" /home/admin/nixos-cp
    echo "Repository successfully copied to /home/admin/nixos-cp."
  else
    echo "Repository is already located at /home/admin/nixos-cp."
  fi
  # Keep ownership as root during the rebuild so git and nix evaluate cleanly without dubious ownership errors
  chown -R root:root /home/admin/nixos-cp 2>/dev/null || true
  chmod 755 /home/admin 2>/dev/null || true

  (cd /home/admin/nixos-cp && git config --add safe.directory '*' 2>/dev/null || true)
  (cd /home/admin/nixos-cp && git add -f hosts/lab-pc/hardware-configuration.nix hosts/lab-pc/configuration.nix 2>/dev/null || true)

  echo "[2/4] Activating and registering default bootloader generation..."
  nixos-rebuild switch --flake /home/admin/nixos-cp#lab-pc

  echo "[3/4] Ensuring admin permissions and passwords on activated generation..."
  chown -R admin:users /home/admin/nixos-cp || true
  chmod 700 /home/admin || true
  su - admin -c "git config --global --add safe.directory '*'" 2>/dev/null || true
  su - admin -c "git config --global user.name admin && git config --global user.email admin@example.com" 2>/dev/null || true
  echo "admin:$ADMIN_PASS" | chpasswd
  echo "root:$ADMIN_PASS" | chpasswd

  echo "[4/4] Deleting other existing user accounts and cleaning home folders..."
  if [ ${#EXISTING_OTHER_USERS[@]} -gt 0 ]; then
    for u in "${EXISTING_OTHER_USERS[@]}"; do
      echo "  Deleting user '$u'..."
      userdel -r -f "$u" 2>/dev/null || userdel -f "$u" 2>/dev/null || true
      if [ -d "/home/$u" ]; then
        rm -rf "/home/$u"
      fi
    done
  fi
  # Clean up any remaining orphaned directories in /home
  for hdir in /home/*; do
    [ -d "$hdir" ] || continue
    bname="$(basename "$hdir")"
    if [ "$bname" != "admin" ] && [ "$bname" != "$CHOSEN_USER" ]; then
      echo "  Removing orphaned directory: $hdir"
      rm -rf "$hdir"
    fi
  done

  echo "=========================================================="
  echo "Configuration successfully applied!"
  echo ""
  echo "Summary:"
  echo "  - Existing disk partitions & filesystems preserved untouched."
  echo "  - Desktop Environment: KDE Plasma 6 (SDDM)"
  echo "  - Participant account: '$CHOSEN_USER' (Auto-login enabled)"
  echo "  - Admin account      : 'admin' (Wheel/sudo privileges, matching root password)"
  echo "  - Admin repository   : Available at /home/admin/nixos-cp"
  echo "  - Other user accounts: Deleted."
  echo "  - Tools & Compilers  : GCC, Clang, Python, Java 21, Rust, Go, VS Code, Code::Blocks"
  echo ""
  echo "Rebooting is strongly recommended to cleanly finalize user cleanup:"
  echo "  sudo reboot"
  echo "=========================================================="
fi
