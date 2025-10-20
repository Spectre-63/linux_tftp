#!/bin/bash
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/../env.conf"

for ver in "${RHEL_VERSIONS[@]}"; do
  SRC="${WWW_ROOT}/${ver}/images/pxeboot"
  DEST="${PXE_ROOT}/${ver}/images/pxeboot"

  if [[ ! -d "$SRC" ]]; then
    echo "Skipping RHEL $ver: $SRC not available or ISO not mounted."
    continue
  fi

  echo "Creating PXE symlink for RHEL $ver..."
  sudo install -d "$(dirname "$DEST")"
  sudo rm -rf "$DEST"
  sudo ln -s "$SRC" "$DEST"
  sudo restorecon -Rv /var/lib/tftpboot
  echo "Linked: $DEST -> $SRC"
done

echo "PXE link creation complete."
