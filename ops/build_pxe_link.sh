# ---------------------------------------------------------------------------
# build_pxe_link <os_name> <version>
# Example: build_pxe_link rocky 10
# Result : /var/lib/tftpboot/rocky/10/images/pxeboot -> /var/www/html/rocky/10/images/pxeboot
# ---------------------------------------------------------------------------
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
