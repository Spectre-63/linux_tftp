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

FAILED=0

fail() {
  should_log error && echo -e "$(timestamp)  \033[1;31m[FAIL]\033[0m  $*"
  ((FAILED++))
}

# --- Optional: display loaded environment for debugging ---------------------
# echo "[DEBUG] Environment loaded:"
# echo "  WWW_BASE=$WWW_BASE"
# echo "  TFTP_BASE=$TFTP_BASE"
# echo "  ISO_DIR=$ISO_DIR"
# --- Runtime options ---------------------------------------------------------
# Controls verbosity (1 = only warnings/failures, 0 = full output)
BRIEF=${BRIEF:-0}

# --- Path definitions --------------------------------------------------------
ISO_DIR="$ISO_DIR"
KEA_SYS_DIR="$KEA_SYS_DIR"
KEA_REPO_DIR="$KEA_REPO_DIR"

echo "=== Sanity Check Report ($(date '+%Y-%m-%d %H:%M:%S')) ==="
[[ $BRIEF -eq 1 ]] && echo "(brief mode: only failures and warnings shown)"
echo


# =============================================================================
# 1. SYSTEMD UNIT AND AUTOMOUNT VALIDATION (multi-distro aware)
# =============================================================================
log_section "SYSTEMD UNIT AND AUTOMOUNT VALIDATION"

info "Detecting var-www-*-*.mount units..."
mapfile -t UNITS < <(
  systemctl list-unit-files 'var-www-*-*.mount' --no-legend 2>/dev/null | awk '{print $1}' | sort || true
)

if [[ ${#UNITS[@]} -eq 0 ]]; then
  fail "No var-www-*-*.mount units found. Did you run generate_mount_units.sh?"
else
  for u in "${UNITS[@]}"; do
    # Expected patterns:
    #   var-www-rhel-9.mount   → distro=rhel, ver=9
    #   var-www-rocky-10.mount → distro=rocky, ver=10
    unit_clean="${u%.mount}"             # remove .mount
    unit_clean="${unit_clean#var-www-}"  # strip leading var-www-
    distro="${unit_clean%%-*}"           # part before first '-'
    ver="${unit_clean#${distro}-}"       # remainder after distro-
    MOUNTPOINT="${WWW_BASE}/${distro}/${ver}"

    if [[ -d "$MOUNTPOINT" ]]; then
      pass "Mount directory exists: $MOUNTPOINT"
    else
      fail "Mount directory missing: $MOUNTPOINT"
    fi

    # --- Check for matching .automount unit ---------------------------------
    auto_unit="${u%.mount}.automount"
    if systemctl list-unit-files "$auto_unit" --no-legend 2>/dev/null | grep -q "$auto_unit"; then
      if systemctl is-enabled "$auto_unit" &>/dev/null; then
        pass "Automount unit present and enabled: $auto_unit"
      else
        warn "Automount unit exists but is not enabled: $auto_unit"
      fi
    else
      warn "No matching automount unit found for $u"
    fi
  done
fi

# --- Check currently active automounts --------------------------------------
info "Checking automount status..."
mapfile -t ACTIVE_AUTOMOUNTS < <(
  systemctl list-units --type=automount --state=active 2>/dev/null | grep 'var-www-' || true
)

if [[ ${#ACTIVE_AUTOMOUNTS[@]} -gt 0 ]]; then
  pass "Active automounts detected (${#ACTIVE_AUTOMOUNTS[@]} total)."
else
  warn "No active automounts found. Run ./enable_all_mounts.sh to activate."
fi


# --- 3. Mount accessibility check ----------------------------------------
log_section "MOUNT ACCESSIBILITY CHECK"

info "Testing mount accessibility..."
for distro in "${!DISTRO_VERSIONS[@]}"; do
  for ver in ${DISTRO_VERSIONS[$distro]}; do
    MOUNT_PATH="${WWW_BASE}/${distro}/${ver}"

    if [[ -d "$MOUNT_PATH" ]]; then
      if sudo ls "$MOUNT_PATH" >/dev/null 2>&1; then
        if mountpoint -q "$MOUNT_PATH"; then
          pass "Mount active and accessible: $MOUNT_PATH"
        else
          warn "Mount exists but not active: $MOUNT_PATH"
        fi
      else
        fail "Cannot access $MOUNT_PATH (permissions or missing mount)."
      fi
    else
      fail "Mount directory missing: $MOUNT_PATH"
    fi
  done
done


# --- 4. PXE/TFTP symlink verification ----------------------------------------
log_section "PXE/TFTP SYMLINK VERIFICATION"
info "Checking PXE/TFTP structure and symlinks..."

if [[ -d "$TFTP_BASE" ]]; then
  for distro in "${!DISTRO_VERSIONS[@]}"; do
    for ver in ${DISTRO_VERSIONS[$distro]}; do
      LINK="${TFTP_BASE}/${distro}/${ver}/images/pxeboot"
      TARGET="${WWW_BASE}/${distro}/${ver}/images/pxeboot"

      # --- Normalize paths ----------------------------------------------------
      CLEAN_LINK="$(echo "$LINK" | sed 's://*:/:g')"
      CLEAN_TARGET="$(echo "$TARGET" | sed 's://*:/:g')"

      if [[ "$LINK" != "$CLEAN_LINK" || "$TARGET" != "$CLEAN_TARGET" ]]; then
        warn "Double slash detected in PXE path:"
        warn "  LINK:    $LINK"
        warn "  TARGET:  $TARGET"
        warn "  Suggested cleanup: check trailing slashes in env.conf or script concatenations."
      fi

      LINK="$CLEAN_LINK"
      TARGET="$CLEAN_TARGET"

      # --- Resolve link and sanitize strings ---------------------------------
      RESOLVED="$(realpath -e "$LINK" 2>/dev/null || readlink -f "$LINK" || echo "$LINK")"
      RESOLVED="${RESOLVED%/}"
      TARGET="${TARGET%/}"
      RESOLVED="${RESOLVED//[[:space:]]/}"
      TARGET="${TARGET//[[:space:]]/}"

      # --- Compare results ----------------------------------------------------
      if [[ -L "$LINK" ]]; then
        if [[ "$RESOLVED" == "$TARGET" ]]; then
          pass "PXE symlink valid for ${distro}-${ver} → $RESOLVED"
        elif [[ "$RESOLVED" == "$TARGET"* ]]; then
          warn "PXE symlink for ${distro}-${ver} resolves deeper than expected:"
          echo "  RESOLVED: $RESOLVED"
          echo "  EXPECTED: $TARGET"
        else
          warn "PXE symlink for ${distro}-${ver} points to unexpected target:"
          echo "  RESOLVED: $RESOLVED"
          echo "  EXPECTED: $TARGET"
        fi
      elif [[ -d "$LINK" ]]; then
        warn "PXE path for ${distro}-${ver} is a directory, not a symlink."
      else
        fail "PXE symlink missing: $LINK"
      fi
    done
  done
else
  fail "PXE root directory missing: $TFTP_BASE"
fi

# --- 5. KEA configuration verification ---------------------------------------
log_section "KEA CONFIGURATION CHECK"
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
log_section "OWNERSHIP VALIDATION"
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
log_section "SELINUX CONTEXT CHECK"
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
hr
echo "Checks complete – total failures: $FAILED"
((FAILED == 0)) && echo -e "\e[32mAll checks passed.\e[0m" || echo -e "\e[31mSome checks failed.\e[0m"



# =============================================================================
# TEMPLATE: Extending Sanity Checks
# -----------------------------------------------------------------------------
# - Add logic below if you want to validate additional repos or configs.
# - Example: check /etc/kea/kea-dhcp4.conf exists or verify PXE templates.
# - Run in brief mode with:
#      ./sanity_check.sh --brief
# =============================================================================
