#!/usr/bin/env bash
# ==============================================================================
# Quick Bootstrap & Installation Script for NixOS CP Lab
# Repository: https://github.com/rezwanahmedratul/nixos-cp
#
# Usage:
#   nix-shell -p git curl vim pciutils --run "bash <(curl -sSL https://raw.githubusercontent.com/rezwanahmedratul/nixos-cp/main/install.sh)"
# Or inside nix-shell:
#   sh <(curl -sSL https://raw.githubusercontent.com/rezwanahmedratul/nixos-cp/main/install.sh)
# ==============================================================================
set -euo pipefail

REPO_URL="https://github.com/rezwanahmedratul/nixos-cp.git"

# Determine target directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/flake.nix" ]; then
  TARGET_DIR="$SCRIPT_DIR"
elif [ "$(id -u -n 2>/dev/null || whoami)" = "admin" ]; then
  TARGET_DIR="/home/admin/nixos-cp"
else
  TARGET_DIR="${HOME}/nixos-cp"
fi

# Ensure essential tools are present; if not, wrap inside nix-shell
REQUIRED_CMDS=("git" "curl" "vim" "lspci")
MISSING=0
for cmd in "${REQUIRED_CMDS[@]}"; do
  if ! command -v "$cmd" &>/dev/null; then
    MISSING=1
    break
  fi
done

if [ "$MISSING" -eq 1 ]; then
  echo "Spawning temporary nix-shell with git, curl, vim, and pciutils..."
  exec nix-shell -p git curl vim pciutils --run "bash <(curl -sSL https://raw.githubusercontent.com/rezwanahmedratul/nixos-cp/main/install.sh) $*"
fi

echo "=========================================================="
echo "    NixOS Competitive Programming Lab - Quick Setup"
echo "=========================================================="

# Clone or update repository if not already running inside it
if [ "$TARGET_DIR" != "$SCRIPT_DIR" ]; then
  if [ -d "$TARGET_DIR/.git" ]; then
    echo "[1/2] Updating existing repository in $TARGET_DIR..."
    git -C "$TARGET_DIR" pull --ff-only 2>/dev/null || true
  else
    echo "[1/2] Cloning $REPO_URL into $TARGET_DIR..."
    rm -rf "$TARGET_DIR"
    git clone "$REPO_URL" "$TARGET_DIR"
  fi
else
  echo "[1/2] Running from local repository at $TARGET_DIR..."
fi

echo "[2/2] Launching unified lab installer..."
cd "$TARGET_DIR"
chmod +x ./scripts/install-lab.sh
exec ./scripts/install-lab.sh "$@"

