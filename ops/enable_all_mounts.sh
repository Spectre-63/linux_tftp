#!/bin/bash
# =============================================================================
# enable_all_mounts.sh
# -----------------------------------------------------------------------------
# Enables and starts all automount units for ISO versions defined in env.conf.
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

for ver in "${RHEL_VERSIONS[@]}"; do
  MOUNT_PATH="/var/www/html/rhel/${ver}"
  UNIT_NAME=$(systemd-escape -p --suffix=automount "$MOUNT_PATH")

  echo "→ Enabling and starting ${UNIT_NAME}"
  sudo systemctl enable --now "$UNIT_NAME"
done

echo
echo "=== All automounts enabled and started. ==="
echo "Verify with:  systemctl list-units | grep rhel"
echo "Or check mounts:  mount | grep /var/www/rhel"
# =============================================================================
# TEMPLATE: Adding a New OS Version
# -----------------------------------------------------------------------------
# 1. Add version to RHEL_VERSIONS in env.conf
# 2. Run generate_mount_units.sh to (re)create units
# 3. Run this script to enable all automounts:
#      ./enable_all_mounts.sh
# =============================================================================
