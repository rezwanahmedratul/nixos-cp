#!/usr/bin/env bash
# ==============================================================================
# Reset Contestant Workspace Across Multiple Lab Computers
# Usage:
#   ./scripts/reset-lab.sh 192.168.1.101 192.168.1.102 ...
# Or with a hosts file:
#   ./scripts/reset-lab.sh $(cat lab-hosts.txt)
# ==============================================================================
set -euo pipefail

if [ "$#" -eq 0 ]; then
  echo "Usage: $0 <host1> [host2 ...]"
  echo "Example: $0 192.168.1.50 192.168.1.51"
  exit 1
fi

for host in "$@"; do
  echo ">>> Resetting contest workspace on $host..."
  ssh -o StrictHostKeyChecking=no "admin@$host" "sudo reset-contest-workspace" || {
    echo "Failed to reset $host" >&2
  }
done

echo ">>> All target lab computers have been reset for the next contest round."

