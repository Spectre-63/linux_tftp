#!/bin/bash
# =============================================================================
# init_pxe_distro.sh
# -----------------------------------------------------------------------------
# Prepares PXE/TFTP structure for a new distro and version.
# Creates the directory hierarchy and symbolic link from TFTP → WWW mount.
#
# Usage:
#   sudo ./init_pxe_distro.sh <distro> <version>
#
# Example:
#   sudo ./init_pxe_distro.sh rhel 10
#
# Result:
#   /var/lib/tftpboot/rhel/10/images/pxeboot -> /var/www/rhel/10/images/pxeboot
# =============================================================================
set -euo pipefail

unset WWW_BASE PXE_ROOT WWW_ROOT TFTP_BASE
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$SCRIPT_DIR/../env.conf" ]]; then
  source "$SCRIPT_DIR/../env.conf"
else
  echo "[FATAL] env.conf not found at expected path: $SCRIPT_DIR/../env.conf" >&2
  exit 1
fi

source "$SCRIPT_DIR/common.sh"

# --- Usage & args -------------------------------------------------------------
DISTRO="${1:-}"
VERSION="${2:-}"

if [[ -z "$DISTRO" || -z "$VERSION" ]]; then
  echo "Usage: $0 <distro> <version>"
  exit 1
fi

SRC="${WWW_BASE}/${DISTRO}/${VERSION}/images/pxeboot"
DEST="${TFTP_BASE}/${DISTRO}/${VERSION}/images/pxeboot"

# --- Verify source path -------------------------------------------------------
if [[ ! -d "$SRC" ]]; then
  fail "Source directory does not exist: $SRC"
  echo "Mount the ISO or verify the path before retrying."
  exit 1
fi

# --- Ensure TFTP directory structure exists -----------------------------------
sudo install -d "$(dirname "$DEST")"

# --- Clean any existing entry -------------------------------------------------
if [[ -L "$DEST" || -d "$DEST" ]]; then
  sudo rm -rf "$DEST"
  info "Removed existing PXE target: $DEST"
fi

# --- Create symlink -----------------------------------------------------------
sudo ln -s "$SRC" "$DEST"
pass "Created PXE symlink: $DEST -> $SRC"

# --- Apply SELinux context (if enabled) ---------------------------------------
if command -v restorecon >/dev/null 2>&1; then
  sudo restorecon -Rv "$WWW_BASE" "$TFTP_BASE" >/dev/null 2>&1 || true
  info "SELinux contexts restored on $WWW_BASE and $TFTP_BASE"
fi

# --- Final confirmation -------------------------------------------------------
if [[ -L "$DEST" ]]; then
  pass "PXE structure ready for ${DISTRO}-${VERSION}"
else
  fail "Failed to create PXE link for ${DISTRO}-${VERSION}"
  exit 1
fi

# =============================================================================
# TEMPLATE: Extending PXE Initialization
# -----------------------------------------------------------------------------
# To add new logic (e.g., auto-registering ISOs or configs):
#   - Add distro/version to DISTRO_VERSIONS in env.conf
#   - Call this script with the new values
# =============================================================================
