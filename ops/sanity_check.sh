#!/bin/bash
# =============================================================================
# sanity_check.sh
# -----------------------------------------------------------------------------
# Performs comprehensive validation of the PXE / ISO / KEA lab environment.
#   • Detects and verifies var-www-rhel-* mount + automount units
#   • Validates PXE/TFTP symlinks
#   • Checks KEA configuration presence and repo sync
#   • Confirms correct ownerships (root vs user)
#   • Warns on SELinux context mismatches
#
# Supports:
#   --brief | -b   → concise output (only FAIL/WARN)
# =============================================================================

set -euo pipefail

# --- Source environment configuration ----------------------------------------
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/../env.conf"


# --- Output helpers ----------------------------------------------------------
BRIEF=0
[[ "${1:-}" =~ ^(--brief|-b)$ ]] && BRIEF=1

pass() { [[ $BRIEF -eq 0 ]] && echo -e "\e[32m[PASS]\e[0m $1"; }
fail() { echo -e "\e[31m[FAIL]\e[0m $1"; FAILED=1; }
warn() { echo -e "\e[33m[WARN]\e[0m $1"; }
info() { [[ $BRIEF -eq 0 ]] && echo -e "\e[34m[INFO]\e[0m $1"; }

FAILED=0

# --- Path definitions --------------------------------------------------------
WWW_BASE="/var/www/rhel"
PXE_ROOT="/var/lib/tftpboot"
ISO_DIR="$ISO_DIR"
KEA_SYS_DIR="$KEA_SYS_DIR"
KEA_REPO_DIR="$KEA_REPO_DIR"

echo "=== Sanity Check Report ($(date '+%Y-%m-%d %H:%M:%S')) ==="
[[ $BRIEF -eq 1 ]] && echo "(brief mode: only failures and warnings shown)"
echo

# --- 1. Detect and validate systemd units ------------------------------------
info "Detecting var-www-rhel-* units..."
mapfile -t UNITS < <(systemctl list-unit-files 'var-www-rhel-*' --no-legend 2>/dev/null | awk '{print $1}' | sort)

if [[ ${#UNITS[@]} -eq 0 ]]; then
  fail "No var-www-rhel-* units found. Did you run generate_mount_units.sh?"
else
  for u in "${UNITS[@]}"; do
    if [[ "$u" == *.mount ]]; then
      ver="${u#var-www-rhel-}"
      ver="${ver%.mount}"
      MOUNTPOINT="${WWW_BASE}/${ver}"
      if [[ -d "$MOUNTPOINT" ]]; then
        pass "Mount directory exists: $MOUNTPOINT"
      else
        fail "Mount directory missing: $MOUNTPOINT"
      fi
    fi
  done
fi

# --- 2. Check automount status -----------------------------------------------
info "Checking automount status..."
mapfile -t ACTIVE_AUTOMOUNTS < <(systemctl list-units --type=automount --state=active | grep var-www-rhel- || true)
if [[ ${#ACTIVE_AUTOMOUNTS[@]} -gt 0 ]]; then
  pass "Active automounts detected."
else
  warn "No active automounts found. Run ./enable_all_mounts.sh to activate."
fi

# --- 3. Verify mount accessibility -------------------------------------------
info "Testing mount accessibility..."
for d in "$WWW_BASE"/*; do
  [[ -d "$d" ]] || continue
  ver=$(basename "$d")
  if sudo ls "$d" >/dev/null 2>&1; then
    if mount | grep -q "$d"; then
      pass "Mount $ver accessible and active."
    else
      warn "Mount $ver accessible but not listed in mount table (idle/unmounted)."
    fi
  else
    fail "Cannot access $d (permissions or missing mount)."
  fi
done

# --- 4. PXE/TFTP symlink verification ----------------------------------------
info "Checking PXE/TFTP structure and symlinks..."
if [[ -d "$PXE_ROOT" ]]; then
  for ver_dir in "$PXE_ROOT"/*; do
    [[ -d "$ver_dir" ]] || continue
    ver=$(basename "$ver_dir")
    LINK="${ver_dir}/images/pxeboot"
    TARGET="${WWW_BASE}/${ver}/images/pxeboot"
    if [[ -L "$LINK" ]]; then
      RESOLVED="$(readlink -f "$LINK")"
      if [[ "$RESOLVED" == "$TARGET" ]]; then
        pass "PXE symlink valid for $ver → $RESOLVED"
      else
        warn "PXE symlink for $ver points to wrong target: $RESOLVED"
      fi
    elif [[ -d "$LINK" ]]; then
      warn "PXE path for $ver is a directory, not a symlink."
    else
      fail "PXE symlink missing: $LINK"
    fi
  done
else
  fail "PXE root directory missing: $PXE_ROOT"
fi

# --- 5. KEA configuration verification ---------------------------------------
info "Checking KEA configuration and repo sync..."

if [[ -d "$KEA_SYS_DIR" ]]; then
  pass "KEA system directory exists: $KEA_SYS_DIR"
  for f in kea-dhcp4.conf kea-dhcp6.conf kea-ctrl-agent.conf; do
    if [[ -f "$KEA_SYS_DIR/$f" ]]; then
      pass "Found system config file: $f"
    else
      warn "Missing expected KEA config file: $KEA_SYS_DIR/$f"
    fi
  done
else
  fail "KEA system directory missing: $KEA_SYS_DIR"
fi

if [[ -d "$KEA_REPO_DIR" ]]; then
  pass "KEA repo directory exists: $KEA_REPO_DIR"
  for f in kea-dhcp4.conf kea-dhcp6.conf kea-ctrl-agent.conf; do
    if [[ -f "$KEA_REPO_DIR/$f" ]]; then
      pass "Found repo config file: $f"
    else
      warn "Missing expected KEA config file in repo: $KEA_REPO_DIR/$f"
    fi
  done
else
  fail "KEA repo directory missing: $KEA_REPO_DIR"
fi

for f in kea-dhcp4.conf kea-dhcp6.conf kea-ctrl-agent.conf; do
  SYS="$KEA_SYS_DIR/$f"
  REPO="$KEA_REPO_DIR/$f"
  if [[ -f "$SYS" && -f "$REPO" ]]; then
    if ! sudo diff -q "$SYS" "$REPO" >/dev/null 2>&1; then
      warn "KEA config $f differs between system and repo."
    fi
  fi
done

# --- 6. Ownership verification -----------------------------------------------
info "Checking KEA ownership consistency..."
USER_NAME=$(whoami)
USER_GROUP=$(id -gn)

# System KEA dir
if [[ -d "$KEA_SYS_DIR" ]]; then
  SYS_OWNER=$(stat -c "%U:%G" "$KEA_SYS_DIR")
  if [[ "$SYS_OWNER" == "root:root" ]]; then
    pass "System KEA directory owned by root:root"
  else
    warn "System KEA directory ownership mismatch: $SYS_OWNER (expected root:root)"
  fi
else
  fail "System KEA directory missing: $KEA_SYS_DIR"
fi

# Repo KEA dir
if [[ -d "$KEA_REPO_DIR" ]]; then
  REPO_OWNER=$(stat -c "%U:%G" "$KEA_REPO_DIR")
  EXPECTED="$USER_NAME:$USER_GROUP"
  if [[ "$REPO_OWNER" == "$EXPECTED" ]]; then
    pass "Repo KEA directory owned by $EXPECTED"
  else
    warn "Repo KEA directory ownership mismatch: $REPO_OWNER (expected $EXPECTED)"
  fi
else
  fail "Repo KEA directory missing: $KEA_REPO_DIR"
fi

# --- 7. SELinux context check ------------------------------------------------
info "Checking SELinux context..."
if command -v getenforce >/dev/null 2>&1; then
  MODE=$(getenforce)
  [[ $BRIEF -eq 0 ]] && echo "SELinux mode: $MODE"
  if [[ "$MODE" != "Disabled" ]]; then
    for path in "$WWW_BASE" "$ISO_DIR" "$PXE_ROOT"; do
      if ls -Zd "$path" 2>/dev/null | grep -vq httpd_sys_content_t; then
        warn "SELinux context on $path may not match expected httpd_sys_content_t."
      fi
    done
  else
    warn "SELinux is disabled — skipping context verification."
  fi
else
  warn "SELinux utilities not found; skipping context verification."
fi

# --- 8. Summary --------------------------------------------------------------
echo
if [[ $FAILED -eq 0 ]]; then
  echo -e "\e[32mAll checks passed.\e[0m"
else
  echo -e "\e[31mOne or more checks failed. Review output above.\e[0m"
fi

# =============================================================================
# TEMPLATE: Extending Sanity Checks
# -----------------------------------------------------------------------------
# - Add logic below if you want to validate additional repos or configs.
# - Example: check /etc/kea/kea-dhcp4.conf exists or verify PXE templates.
# - Run in brief mode with:
#      ./sanity_check.sh --brief
# =============================================================================
