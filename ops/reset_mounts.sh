#!/bin/bash
# =============================================================================
# reset_mounts.sh
# -----------------------------------------------------------------------------
# Safely stops, disables, and removes all var-www-rhel-* mount/automount units.
# Run before regenerating new units.
# =============================================================================

#!/bin/bash
# =============================================================================
# Standard Ops Script Header
# Ensures consistent environment, prevents stale variable reuse, and
# dynamically locates env.conf regardless of where the script is executed.
# =============================================================================
set -euo pipefail

# --- Prevent stale or legacy variables from interfering ---------------------
unset WWW_BASE PXE_ROOT WWW_ROOT TFTP_BASE

# --- Resolve this script's directory ----------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Load shared environment configuration ----------------------------------
if [[ -f "$SCRIPT_DIR/../env.conf" ]]; then
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/../env.conf"
else
  echo "[FATAL] env.conf not found at expected path: $SCRIPT_DIR/../env.conf" >&2
  exit 1
fi

source "$SCRIPT_DIR/common.sh"

# --- Optional: display loaded environment for debugging ---------------------
# echo "[DEBUG] Environment loaded:"
# echo "  WWW_BASE=$WWW_BASE"
# echo "  TFTP_BASE=$TFTP_BASE"
# echo "  ISO_DIR=$ISO_DIR"

SYSTEMD_DIR="/etc/systemd/system"

echo "=== Resetting RHEL/ISO mount units ==="

# Find and process all related units
mapfile -t UNITS < <(sudo systemctl list-unit-files 'var-www-rhel-*' --no-legend 2>/dev/null | awk '{print $1}')

if [[ ${#UNITS[@]} -eq 0 ]]; then
  echo "No matching units found — nothing to reset."
else
  echo "Disabling and stopping units..."
  for unit in "${UNITS[@]}"; do
    echo "→ $unit"
    sudo systemctl disable --now "$unit" >/dev/null 2>&1 || true
  done

  echo "Removing unit files..."
  for f in "$SYSTEMD_DIR"/var-www-rhel-*{.mount,.automount}; do
    [[ -e "$f" ]] || continue
    echo "→ Removing $(basename "$f")"
    sudo rm -f "$f"
  done
fi

echo
echo "Reloading systemd..."
sudo systemctl daemon-reload

echo
echo "=== Reset complete. ==="
echo "You may now regenerate units with:"
echo "    ./generate_mount_units.sh"
echo
echo "To verify:"
echo "    systemctl list-unit-files | grep rhel"
# =============================================================================
# TEMPLATE: Usage Reference
# -----------------------------------------------------------------------------
# 1. Run this to clean the environment:
#      ./reset_mounts.sh
# 2. Regenerate units:
#      ./generate_mount_units.sh
# 3. Re-enable mounts:
#      ./enable_all_mounts.sh
# 4. Verify with:
#      mount | grep /var/www/rhel
# =============================================================================
