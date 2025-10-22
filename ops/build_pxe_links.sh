#!/bin/bash
# =============================================================================
# build_pxe_links.sh
# -----------------------------------------------------------------------------
# Creates PXE boot symlinks under /var/lib/tftpboot for each distro/version.
# These link into the mounted /var/www/<distro>/<version>/images/pxeboot paths.
#
# Usage: sudo ./build_pxe_links.sh
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

# --- Optional: display loaded environment for debugging ---------------------
# echo "[DEBUG] Environment loaded:"
# echo "  WWW_BASE=$WWW_BASE"
# echo "  TFTP_BASE=$TFTP_BASE"
# echo "  ISO_DIR=$ISO_DIR"

source "$SCRIPT_DIR/common.sh"

# -----------------------------------------------------------------------------
# Load environment configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../env.conf"

echo "=== Building PXE boot symlinks ==="
echo

# -----------------------------------------------------------------------------
# Iterate through each defined distro and version
# -----------------------------------------------------------------------------
for distro in "${!DISTRO_VERSIONS[@]}"; do
  for ver in ${DISTRO_VERSIONS[$distro]}; do
    web_pxeboot="${WWW_BASE}/${distro}/${ver}/images/pxeboot"
    tftp_pxeboot="${TFTP_BASE}/${distro}/${ver}/images"

    # Validate source
    if [[ ! -d "$web_pxeboot" ]]; then
      echo "[WARN] Skipping ${distro}-${ver}: missing source ${web_pxeboot}"
      continue
    fi

    # Ensure TFTP target structure exists
    echo "[INFO] Ensuring TFTP path: $tftp_pxeboot"
    sudo mkdir -p "$tftp_pxeboot"

    # Link target
    link_target="${tftp_pxeboot}/pxeboot"

    # Remove stale link or directory if needed
    if [[ -L "$link_target" || -d "$link_target" ]]; then
      sudo rm -rf "$link_target"
    fi

    echo "[LINK] ${link_target} → ${web_pxeboot}"
    sudo ln -s "$web_pxeboot" "$link_target"
  done
done

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo
echo "PXE symlink build complete. Current links under $TFTP_BASE:"
sudo find "$TFTP_BASE" -type l -ls | awk '{print "  " $11 " -> " $13}'
echo
echo "Done!"
