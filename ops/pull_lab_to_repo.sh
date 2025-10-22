#!/bin/bash
# =============================================================================
# pull_lab_to_repo.sh
# -----------------------------------------------------------------------------
# Pull configuration and content files from live directories into central repo
# while retaining permissions, ownership, and timestamps.
# After pull, repo files are re-owned by the current user for Git compatibility.
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

EXCLUDE_FILE="$REPO_BASE/.rsync-exclude"
RSYNC_OPTS="-avh --delete --exclude-from=$EXCLUDE_FILE"

declare -A MAP=(
  ["/var/lib/tftpboot"]="$REPO_BASE/tftpboot"
  ["/etc/kea"]="$REPO_BASE/kea"
  ["/var/www/html"]="$REPO_BASE/www/html"
)

echo "=== Pulling live files into repository ==="
for SRC in "${!MAP[@]}"; do
  DEST="${MAP[$SRC]}"
  echo
  echo "Syncing: $SRC → $DEST"
  mkdir -p "$DEST"

  if [[ "$SRC" == /etc/* ]]; then
    echo "Using sudo for $SRC..."
    sudo rsync $RSYNC_OPTS "$SRC"/ "$DEST"/
  else
    rsync $RSYNC_OPTS "$SRC"/ "$DEST"/
  fi

  # Re-own the pulled files so Git can manage them
  echo "Normalizing ownership for repo copy..."
  sudo chown -R "$(whoami):$(id -gn)" "$DEST"
done

echo
echo "Restoring SELinux context (if applicable)..."
restorecon -Rv "$REPO_BASE" >/dev/null 2>&1 || true

echo
echo "Pull complete. Repository is updated and ownership normalized."
