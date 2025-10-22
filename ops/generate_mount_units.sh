#!/bin/bash
# =============================================================================
# generate_mount_units.sh
# -----------------------------------------------------------------------------
# Generate per-version .mount and .automount units for each ISO listed in env.conf
# and remove obsolete ones no longer referenced.
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

echo "=== Generating mount and automount units in $SYSTEMD_DIR ==="

# Track generated unit names
declare -A KEEP_UNITS

for ver in "${RHEL_VERSIONS[@]}"; do
  SRC_ISO="$ISO_BASE/rhel-${ver}.iso"
  MOUNT_PATH="$WWW_BASE/${ver}"
  UNIT_NAME=$(systemd-escape -p --suffix=mount "$MOUNT_PATH")
  AUTO_NAME="${UNIT_NAME%.mount}.automount"

  KEEP_UNITS["$UNIT_NAME"]=1
  KEEP_UNITS["$AUTO_NAME"]=1

  echo "→ Creating units for version $ver: $UNIT_NAME / $AUTO_NAME"

  # Create mount unit
  sudo tee "$SYSTEMD_DIR/$UNIT_NAME" >/dev/null <<EOF
[Unit]
Description=RHEL ${ver} ISO mount for Apache

[Mount]
What=${SRC_ISO}
Where=${MOUNT_PATH}
Type=iso9660
Options=loop,ro,context=system_u:object_r:httpd_sys_content_t:s0

[Install]
WantedBy=multi-user.target
EOF

  # Create automount unit
  sudo tee "$SYSTEMD_DIR/$AUTO_NAME" >/dev/null <<EOF
[Unit]
Description=Automount for RHEL ${ver} ISO

[Automount]
Where=${MOUNT_PATH}
TimeoutIdleSec=600

[Install]
WantedBy=multi-user.target
EOF

  sudo mkdir -p "$MOUNT_PATH"
done

# --- Cleanup phase ------------------------------------------------------------
echo
echo "=== Cleaning obsolete units not in env.conf ==="
for f in "$SYSTEMD_DIR"/var-www-rhel-*{.mount,.automount}; do
  [[ -e "$f" ]] || continue
  base=$(basename "$f")
  if [[ -z "${KEEP_UNITS[$base]:-}" ]]; then
    echo "Removing obsolete unit: $base"
    sudo systemctl disable --now "$base" >/dev/null 2>&1 || true
    sudo rm -f "$f"
  fi
done

# --- Reload systemd -----------------------------------------------------------
echo
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

echo
echo "=== Done. ==="
echo "Use 'systemctl enable --now <unit>.automount' to activate automounts, e.g.:"
echo "    sudo systemctl enable --now var-www-rhel-9.automount"
echo "    sudo systemctl enable --now var-www-rhel-10.automount"

# =============================================================================
# TEMPLATE: Adding a New OS Version
# -----------------------------------------------------------------------------
# 1. Add the new version ID to RHEL_VERSIONS in env.conf, e.g.:
#      RHEL_VERSIONS=(9 10 rocky10 11)
# 2. Ensure its ISO exists under \$ISO_BASE (e.g. rhel-11.iso)
# 3. Run this script again:
#      ./generate_mount_units.sh
# 4. Enable automount:
#      sudo systemctl enable --now var-www-rhel-11.automount
# 5. Verify:
#      mount | grep rhel
# =============================================================================
