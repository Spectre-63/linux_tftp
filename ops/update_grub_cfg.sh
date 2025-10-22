#!/bin/bash
# =============================================================================
# update_grub_cfg.sh
# ----------------------------------------------------------------------------- 
# Full rebuild of PXE link structure + GRUB boot menu.
#
# 1. Ensures PXE symlinks exist for all configured distros/versions
# 2. Rebuilds /var/lib/tftpboot/uefi/grub.cfg dynamically
# 3. Commits to Git if configuration changed
#
# Depends on:
#   - env.conf for WWW_BASE, TFTP_BASE, DISTRO_VERSIONS
#   - common.sh for log formatting (optional)
#   - build_pxe_links.sh (optional, if PXE links need regeneration)
# =============================================================================
set -euo pipefail

unset WWW_BASE TFTP_BASE
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Load environment --------------------------------------------------------
if [[ -f "$SCRIPT_DIR/../env.conf" ]]; then
  source "$SCRIPT_DIR/../env.conf"
else
  echo "[FATAL] env.conf not found at: $SCRIPT_DIR/../env.conf" >&2
  exit 1
fi

[[ -f "$SCRIPT_DIR/common.sh" ]] && source "$SCRIPT_DIR/common.sh"

GRUB_FILE="${TFTP_BASE}/uefi/grub.cfg"
TMP_FILE=$(mktemp)
REPO_DIR="$REPO_BASE"
SERVER_IP=$(ip -4 addr show | awk '/inet/ && !/127.0.0.1/ { sub("/.*","",$2); print $2; exit }')

# =============================================================================
# 1. Optional PXE Link Rebuild
# =============================================================================
if [[ -x "$SCRIPT_DIR/build_pxe_links.sh" ]]; then
  log_section "REBUILDING PXE LINK STRUCTURE"
  "$SCRIPT_DIR/build_pxe_links.sh" || warn "PXE link regeneration failed or incomplete."
else
  warn "build_pxe_links.sh not found — skipping PXE link regeneration."
fi

# =============================================================================
# 2. Rebuild PXE boot binaries
# =============================================================================

if [[ -x "$SCRIPT_DIR/rebuild_pxe_boot_binaries.sh" ]]; then
  log_section "SYNCING PXE BOOT BINARIES"
  "$SCRIPT_DIR/rebuild_pxe_boot_binaries.sh"
fi


# =============================================================================
# 3. GRUB CONFIG REBUILD
# =============================================================================
log_section "REGENERATING GRUB CONFIG"

{
  echo "set timeout=5"
  echo "set default=0"
  echo "# Auto-generated $(date)"
  echo "set net_default_server=${SERVER_IP}"
  echo "set root=(tftp,${SERVER_IP})"
  echo "set prefix=(tftp,${SERVER_IP})/uefi"
  echo "set color_normal=light-gray/black"
  echo "set color_highlight=yellow/black"
  echo
} > "$TMP_FILE"

for distro in "${!DISTRO_VERSIONS[@]}"; do
  for ver in ${DISTRO_VERSIONS[$distro]}; do
    SRC_PATH="${WWW_BASE}/${distro}/${ver}"
    PXE_VMLINUZ="${TFTP_BASE}/${distro}/${ver}/images/pxeboot/vmlinuz"
    PXE_INITRD="${TFTP_BASE}/${distro}/${ver}/images/pxeboot/initrd.img"
    KS_PATH="http://${SERVER_IP}/${distro}/${ver}/ks.cfg"

    if [[ -d "$SRC_PATH" && -f "$PXE_VMLINUZ" && -f "$PXE_INITRD" ]]; then
      if [[ -d "${SRC_PATH}/BaseOS" ]]; then
        STAGE2_URL="http://${SERVER_IP}/${distro}/${ver}/BaseOS/"
        REPO_URL="http://${SERVER_IP}/${distro}/${ver}/BaseOS/"
      else
        STAGE2_URL="http://${SERVER_IP}/${distro}/${ver}/"
        REPO_URL="http://${SERVER_IP}/${distro}/${ver}/"
      fi

      {
        echo "menuentry '${distro^^} ${ver} Automated Install' {"
        echo "  linuxefi /${distro}/${ver}/images/pxeboot/vmlinuz ip=dhcp rd.neednet=1 rd.net.timeout.carrier=60 rd.driver.pre=hv_vmbus rd.driver.pre=hv_netvsc rd.driver.pre=hv_storvsc inst.stage2=${STAGE2_URL} inst.repo=${REPO_URL} inst.ks=${KS_PATH}"
        echo "  initrdefi /${distro}/${ver}/images/pxeboot/initrd.img"
        echo "}"
        echo
      } >> "$TMP_FILE"

      pass "Added GRUB entry for ${distro^^} ${ver}"
    else
      warn "Skipping ${distro^^} ${ver}: missing PXE assets or mount path."
    fi
  done
done

sudo install -Dm644 "$TMP_FILE" "$GRUB_FILE"
sudo restorecon -v "$GRUB_FILE" >/dev/null 2>&1 || true
rm -f "$TMP_FILE"

log_section "GRUB CONFIG UPDATED"
pass "Wrote $(wc -l < "$GRUB_FILE") lines to $GRUB_FILE"

# =============================================================================
# 4. GIT AUTO-VERSIONING
# =============================================================================
log_section "GIT VERSIONING"

if [[ -d "$REPO_DIR/.git" ]]; then
  pushd "$REPO_DIR" >/dev/null
  git config --global --add safe.directory "$REPO_DIR" || true
  REL_PATH=$(realpath --relative-to="$REPO_DIR" "$GRUB_FILE" 2>/dev/null || echo "$GRUB_FILE")
  git add "$REL_PATH"

  if ! git diff --cached --quiet; then
    COMMIT_MSG="Auto-update GRUB + PXE links ($(date '+%Y-%m-%d %H:%M:%S'))"
    git commit -m "$COMMIT_MSG" >/dev/null
    git push origin main >/dev/null 2>&1 || warn "Push skipped or failed (offline repo?)"
    pass "Committed GRUB update: $COMMIT_MSG"
  else
    info "No changes detected in $REL_PATH — skipping commit."
  fi

  popd >/dev/null
else
  warn "Not a Git repo: skipping commit phase."
fi

log_section "GRUB + PXE UPDATE COMPLETE"
