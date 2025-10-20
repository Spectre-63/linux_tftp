#!/bin/bash
# =============================================================================
# push_repo_to_lab.sh
# -----------------------------------------------------------------------------
# Push configuration and content files from repo back to live system.
# Ensures correct ownership and permissions on destination.
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/../env.conf"

EXCLUDE_FILE="$REPO_BASE/.rsync-exclude"
RSYNC_OPTS="-avh --delete --exclude-from=$EXCLUDE_FILE"

declare -A MAP=(
  ["$REPO_BASE/tftpboot"]="/var/lib/tftpboot"
  ["$REPO_BASE/kea"]="/etc/kea"
  ["$REPO_BASE/www/html"]="/var/www/html"
)

echo "=== Pushing repository content to live system ==="
for SRC in "${!MAP[@]}"; do
  DEST="${MAP[$SRC]}"
  echo
  echo "Syncing: $SRC → $DEST"
  sudo rsync $RSYNC_OPTS "$SRC"/ "$DEST"/

  # Reapply correct ownership based on target
  case "$DEST" in
    /etc/kea)
      echo "Setting ownership: root:root on $DEST"
      sudo chown -R root:root "$DEST"
      ;;
    /var/www/html)
      echo "Setting ownership: apache:apache on $DEST"
      sudo chown -R apache:apache "$DEST"
      ;;
    /var/lib/tftpboot)
      echo "Setting ownership: tftp:tftp (if exists) on $DEST"
      if id tftp &>/dev/null; then
        sudo chown -R tftp:tftp "$DEST"
      else
        sudo chown -R nobody:nobody "$DEST"
      fi
      ;;
  esac
done

echo
echo "Restoring SELinux context (if applicable)..."
sudo restorecon -Rv /var/lib/tftpboot /etc/kea /var/www/html >/dev/null 2>&1 || true

echo
echo "Push complete. Live environment refreshed with correct ownerships."
