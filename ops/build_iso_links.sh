#!/bin/bash
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/../env.conf"


declare -A FILES=(
  ["9"]="rhel-9.6-x86_64-dvd.iso"
  ["10"]="rhel-10.0-x86_64-dvd.iso"
   ["rocky10"]="Rocky-10.0-x86_64-dvd.iso"
)

echo "=== Updating ISO symlinks in $ISO_DIR ==="
for ver in "${!FILES[@]}"; do
  TARGET="${ISO_DIR}/${FILES[$ver]}"
 # Use RHEL- or Rocky- prefix dynamically
  case "$ver" in
    rocky*) LINK="${ISO_DIR}/Rocky-${ver#rocky}.iso" ;;
    *)      LINK="${ISO_DIR}/RHEL-${ver}.iso" ;;
  esac
  if [[ -f "$TARGET" ]]; then
    ln -sf "$TARGET" "$LINK"
    echo "Linked: $LINK -> $(basename "$TARGET")"
  else
    echo "Warning: ISO not found for RHEL $ver at $TARGET" >&2
  fi
done

echo "Reloading systemd automount units..."
sudo systemctl daemon-reload
for ver in "${RHEL_VERSIONS[@]}"; do
  sudo systemctl restart "var-www-rhel@${ver}.automount"
done

echo "ISO symlink update complete."


# =============================================================================
# TEMPLATE: Adding a New OS Version
# -----------------------------------------------------------------------------
# 1. Add your new version identifier to RHEL_VERSIONS in env.conf, e.g.:
#      RHEL_VERSIONS=("9" "10" "rocky10" "rhel11")
#
# 2. Add the corresponding ISO filename to the FILES map above, e.g.:
#      ["rhel11"]="rhel-11.0-x86_64-dvd.iso"
#
# 3. Place the ISO file in:  $ISO_DIR
# 4. Run:
#      ./build_iso_links.sh
#      ./build_pxe_links.sh
# 5. Verify using:
#      ./sanity_check.sh
# =============================================================================
