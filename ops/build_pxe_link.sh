# ---------------------------------------------------------------------------
# build_pxe_link <os_name> <version>
# Example: build_pxe_link rocky 10
# Result : /var/lib/tftpboot/rocky/10/images/pxeboot -> /var/www/html/rocky/10/images/pxeboot
# ---------------------------------------------------------------------------
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

build_pxe_link() {
    local OS_NAME="$1"
    local OS_VER="$2"

    if [[ -z "$OS_NAME" || -z "$OS_VER" ]]; then
        echo "Usage: build_pxe_link <os_name> <version>"
        return 1
    fi

    local SRC="/var/www/html/${OS_NAME}/${OS_VER}/images/pxeboot"
    local DEST="/var/lib/tftpboot/${OS_NAME}/${OS_VER}/images/pxeboot"

    # Create parent directories under tftpboot if needed
    sudo install -d "$(dirname "$DEST")"

    # Remove any existing directory or stale link before re-creating
    if [[ -e "$DEST" || -L "$DEST" ]]; then
        sudo rm -rf "$DEST"
    fi

    # Create the symlink
    sudo ln -s "$SRC" "$DEST"

    echo "Linked: $DEST -> $SRC"

    # Fix SELinux labels so tftp/http can traverse themsudo mkdir -p /var/www/rhel/9
sudo mkdir -p /var/www/rhel/10
    sudo restorecon -Rv /var/www/html /var/lib/tftpboot
}
