#!/bin/bash
# =============================================================================
# repair_kea_sync.sh
# -----------------------------------------------------------------------------
# Synchronizes KEA configuration files between system and repo.
# Sources env.conf for path definitions.
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

AUTO_MODE=0
[[ "${1:-}" =~ ^(--auto|-a)$ ]] && AUTO_MODE=1

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "=== KEA Configuration Synchronization ($TIMESTAMP) ==="

# --- 1. Safety checks ---------------------------------------------------------
if [[ ! -d "$KEA_SYS_DIR" ]]; then
  echo "[FAIL] System KEA directory missing: $KEA_SYS_DIR"
  exit 1
fi
if [[ ! -d "$KEA_REPO_DIR" ]]; then
  echo "[FAIL] Repo KEA directory missing: $KEA_REPO_DIR"
  exit 1
fi

FILES=(kea-dhcp4.conf kea-dhcp6.conf kea-ctrl-agent.conf)
UPDATED_SYS=0
UPDATED_REPO=0

# --- 2. Sync loop -------------------------------------------------------------
for f in "${FILES[@]}"; do
  SYS="$KEA_SYS_DIR/$f"
  REPO="$KEA_REPO_DIR/$f"
  # ... [sync logic unchanged] ...
done

# --- 3. Syntax validation -----------------------------------------------------
SYNTAX_OK=0
if command -v kea-dhcp4 >/dev/null 2>&1; then
  echo
  echo "Validating KEA syntax..."
  if sudo kea-dhcp4 -t "$KEA_SYS_DIR/kea-dhcp4.conf" >/dev/null; then
    echo "[PASS] kea-dhcp4.conf syntax valid"
    SYNTAX_OK=1
  else
    echo "[FAIL] kea-dhcp4.conf syntax check failed!"
  fi
else
  echo
  echo "[INFO] KEA binaries not found — skipping syntax test."
fi

# --- 4. Optional service restart ---------------------------------------------
# ... [no change, still conditional on AUTO_MODE and SYNTAX_OK] ...
