#!/bin/bash
# =============================================================================
# enable_all_mounts.sh
# -----------------------------------------------------------------------------
# Enables and starts all automount units for ISO versions defined in env.conf.
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/../env.conf"

for ver in "${RHEL_VERSIONS[@]}"; do
  MOUNT_PATH="/var/www/rhel/${ver}"
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
