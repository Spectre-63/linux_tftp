#!/bin/bash
# =============================================================================
# rebuild_pxe_boot_binaries.sh
# -----------------------------------------------------------------------------
# Ensures PXE boot assets (vmlinuz, initrd.img) are properly linked only if
# the pxeboot directory is *not already* a symlink to /var/www/<distro>/<ver>.
# =============================================================================
set -euo pipefail

unset WWW_BASE TFTP_BASE
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$SCRIPT_DIR/../env.conf" ]]; then
  source "$SCRIPT_DIR/../env.conf"
else
  echo "[FATAL] env.conf not found at: $SCRIPT_DIR/../env.conf" >&2
  exit 1
fi

[[ -f "$SCRIPT_DIR/common.sh" ]] && source "$SCRIPT_DIR/common.sh"

log_section "REBUILDING PXE BOOT BINARIES"

for distro in "${!DISTRO_VERSIONS[@]}"; do
  for ver in ${DISTRO_VERSIONS[$distro]}; do
    SRC_DIR="${WWW_BASE}/${distro}/${ver}/images/pxeboot"
    DEST_DIR="${TFTP_BASE}/${distro}/${ver}/images/pxeboot"

    # --- Skip if pxeboot itself is already a symlink -------------------------
    if [[ -L "$DEST_DIR" ]]; then
      info "Skipping ${distro^^} ${ver} — pxeboot is already a symlink."
      continue
    fi

    if [[ -d "$SRC_DIR" ]]; then
      sudo mkdir -p "$DEST_DIR"

      for f in vmlinuz initrd.img; do
        SRC_FILE="${SRC_DIR}/${f}"
        DEST_LINK="${DEST_DIR}/${f}"

        if [[ -e "$SRC_FILE" ]]; then
          sudo ln -sf "$SRC_FILE" "$DEST_LINK"
          pass "Linked $DEST_LINK → $SRC_FILE"
        else
          warn "Missing source file: $SRC_FILE (skipping)"
        fi
      done
    else
      warn "No source path for ${distro^^} ${ver}: $SRC_DIR missing"
    fi
  done
done

sudo restorecon -Rv /var/lib/tftpboot >/dev/null 2>&1 || true
log_section "PXE BOOT BINARIES REBUILT"
