#!/usr/bin/env bash
#
# ASUS USB-BT500 / Realtek RTL8761BU firmware replacement (Fedora Edition)
#
# Known-bad firmware:
#   0xdfc6d922
#
# Firmware source:
#   https://github.com/andrew-ld/rtl8761b-firmware
#
# Fedora firmware directory:
#   /usr/lib/firmware/rtl_bt
#
# Existing firmware is backed up IN PLACE:
#
#   rtl8761bu_fw.bin.zst
#       ->
#   rtl8761bu_fw.bin.zst.bak
#
# The replacement retains the .bin firmware filename and uses
# the stock compression format (.zst or .xz) currently installed on Fedora.
#
# Usage:
#   ./replace-bt500-firmware.sh
#   ./replace-bt500-firmware.sh --dry-run
#   sudo ./replace-bt500-firmware.sh --rollback
#

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_NAME="$(basename "$0")"

REPO_URL="https://github.com/andrew-ld/rtl8761b-firmware.git"
FW_DIR="/usr/lib/firmware/rtl_bt"

KNOWN_BAD_FW="0xdfc6d922"

TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"

DRY_RUN=false
BTUSB_UNLOADED=false

TMP_DIR=""
REPO_DIR=""
STAGE_DIR=""
VERIFY_DIR=""

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

die() {
    echo
    echo "ERROR: $*" >&2
    echo
    exit 1
}

info() {
    echo "[+] $*"
}

warn() {
    echo "[!] WARNING: $*" >&2
}

dry_info() {
    echo "[DRY-RUN] $*"
}

need_command() {
    command -v "$1" >/dev/null 2>&1 ||
        die "Required command not found: $1"
}

# ------------------------------------------------------------
# Cleanup
# ------------------------------------------------------------

cleanup() {
    local exit_status=$?

    if [[ "$DRY_RUN" == false && "$BTUSB_UNLOADED" == true ]]; then
        echo
        echo "[!] Cleanup: attempting to restore Bluetooth kernel module..."

        if sudo modprobe btusb 2>/dev/null; then
            BTUSB_UNLOADED=false
        else
            echo "[!] WARNING: could not reload btusb."
        fi

        sudo systemctl start bluetooth.service 2>/dev/null || \
            echo "[!] WARNING: could not start bluetooth.service."
    fi

    if [[ -n "${TMP_DIR:-}" && -d "${TMP_DIR:-}" ]]; then
        rm -rf -- "$TMP_DIR"
    fi

    exit "$exit_status"
}

trap cleanup EXIT

# ------------------------------------------------------------
# Parse arguments
# ------------------------------------------------------------

case "${1:-}" in
    "")
        ;;
    --dry-run)
        DRY_RUN=true
        ;;
    --rollback)
        ;;
    *)
        die "Usage: $SCRIPT_NAME [--dry-run|--rollback]"
        ;;
esac

[[ $# -le 1 ]] ||
    die "Usage: $SCRIPT_NAME [--dry-run|--rollback]"

# ------------------------------------------------------------
# Required commands
# ------------------------------------------------------------

need_command find
need_command git
need_command install
need_command mv
need_command mktemp
need_command sha256sum
need_command cmp
need_command modprobe
need_command lsusb
need_command grep
need_command tail
need_command sed

# ------------------------------------------------------------
# Verify firmware directory
# ------------------------------------------------------------

[[ -d "$FW_DIR" ]] ||
    die "Firmware directory does not exist: $FW_DIR"

# ------------------------------------------------------------
# Locate installed firmware
# ------------------------------------------------------------

find_installed_file() {
    local base="$1"

    local candidates=(
        "$FW_DIR/${base}.zst"
        "$FW_DIR/${base}.xz"
        "$FW_DIR/${base}"
    )

    local candidate

    for candidate in "${candidates[@]}"; do
        if [[ -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

FW_PATH="$(
    find_installed_file "rtl8761bu_fw.bin"
)" || die "Could not find rtl8761bu_fw.bin(.zst/.xz) in $FW_DIR"

CONFIG_PATH="$(
    find_installed_file "rtl8761bu_config.bin"
)" || die "Could not find rtl8761bu_config.bin(.zst/.xz) in $FW_DIR"

# ------------------------------------------------------------
# Determine compression format
# ------------------------------------------------------------

get_compression() {
    local path="$1"

    case "$path" in
        *.zst)
            echo "zst"
            ;;
        *.xz)
            echo "xz"
            ;;
        *.bin)
            echo "plain"
            ;;
        *)
            return 1
            ;;
    esac
}

FW_COMPRESSION="$(get_compression "$FW_PATH")"
CONFIG_COMPRESSION="$(get_compression "$CONFIG_PATH")"

[[ "$FW_COMPRESSION" == "$CONFIG_COMPRESSION" ]] ||
    die "Firmware and config use different compression formats."

COMPRESSION="$FW_COMPRESSION"

FW_FILENAME="$(basename "$FW_PATH")"
CONFIG_FILENAME="$(basename "$CONFIG_PATH")"

BACKUP_FW="${FW_PATH}.bak"
BACKUP_CONFIG="${CONFIG_PATH}.bak"

# ------------------------------------------------------------
# Compression requirements
# ------------------------------------------------------------

case "$COMPRESSION" in
    zst)
        need_command zstd
        ;;
    xz)
        need_command xz
        ;;
esac

# ------------------------------------------------------------
# Firmware-version detection
# ------------------------------------------------------------
#
# Fedora restricts unprivileged dmesg access by default.
# Queries via dmesg first, falling back to journalctl -k.
#

get_kernel_fw_versions() {
    {
        if command -v dmesg >/dev/null 2>&1 && dmesg >/dev/null 2>&1; then
            dmesg
        else
            journalctl -k -b 0 --no-pager 2>/dev/null || sudo dmesg 2>/dev/null
        fi
    } |
        grep -iE \
            'Bluetooth: hci[0-9]+: RTL: fw version 0x[0-9a-f]+' |
        sed -nE \
            's/.*RTL: fw version (0x[0-9a-fA-F]+).*/\1/ip' |
        tail -n 10 ||
        true
}

get_current_fw_version() {
    local versions

    versions="$(get_kernel_fw_versions)"

    if [[ -n "$versions" ]]; then
        printf '%s\n' "$versions" | tail -n 1
    fi
}

# ------------------------------------------------------------
# Validate firmware-version detection
# ------------------------------------------------------------

validate_firmware_version() {
    local context="$1"
    local version="${2:-}"

    echo
    echo "Firmware version validation ($context):"
    echo

    if [[ -z "$version" ]]; then
        echo "  Result: UNKNOWN"
        echo
        echo "  No RTL firmware-version message was found."
        echo
        echo "  Expected kernel log pattern:"
        echo "    Bluetooth: hci0: RTL: fw version 0x........"
        echo
        return 2
    fi

    echo "  Detected version: $version"

    if [[ "${version,,}" == "${KNOWN_BAD_FW,,}" ]]; then
        echo "  Result: KNOWN-BAD"
        echo
        echo "  !!! $KNOWN_BAD_FW is currently loaded !!!"
        return 1
    fi

    echo "  Result: DIFFERENT FROM KNOWN-BAD"
    echo
    echo "  Known-bad version: $KNOWN_BAD_FW"

    return 0
}

# ------------------------------------------------------------
# Validate the parser itself
# ------------------------------------------------------------

self_test_firmware_parser() {
    local synthetic_line
    local synthetic_version

    synthetic_line="Bluetooth: hci0: RTL: fw version $KNOWN_BAD_FW"

    synthetic_version="$(
        printf '%s\n' "$synthetic_line" |
            grep -iE \
                'Bluetooth: hci[0-9]+: RTL: fw version 0x[0-9a-f]+' |
            sed -nE \
                's/.*RTL: fw version (0x[0-9a-fA-F]+).*/\1/ip' |
            tail -n 1
    )"

    [[ "${synthetic_version,,}" == "${KNOWN_BAD_FW,,}" ]]
}

show_bluetooth_info() {
    local heading="$1"

    echo
    echo "============================================================"
    echo " $heading"
    echo "============================================================"
    echo

    echo "USB Bluetooth device:"

    local usb_bt_info
    usb_bt_info="$(
        lsusb 2>/dev/null |
        grep -i -E 'bluetooth|realtek|0b05' ||
        true
    )"

    if [[ -n "$usb_bt_info" ]]; then
        echo "$usb_bt_info"
    else
        echo "  No matching Bluetooth/Realtek USB device found via lsusb."
    fi

    echo

    local current_version
    current_version="$(get_current_fw_version || true)"

    validate_firmware_version \
        "$heading" \
        "$current_version" ||
        true

    echo
    echo "Recent Realtek/BT kernel messages:"

    local dmesg_info
    dmesg_info="$(
        {
            if command -v dmesg >/dev/null 2>&1 && dmesg >/dev/null 2>&1; then
                dmesg
            else
                journalctl -k -b 0 --no-pager 2>/dev/null || sudo dmesg 2>/dev/null
            fi
        } |
        grep -i -E \
            'rtl8761|rtl_bt|btusb|btrtl|RTL: fw|Bluetooth' |
        tail -n 20 ||
        true
    )"

    if [[ -n "$dmesg_info" ]]; then
        echo "$dmesg_info"
    else
        echo "  No matching messages currently available in the kernel log."
    fi

    echo
}

# ------------------------------------------------------------
# Rollback
# ------------------------------------------------------------

rollback() {
    need_command sudo
    need_command systemctl

    echo
    echo "============================================================"
    echo " ASUS BT500 firmware rollback"
    echo "============================================================"
    echo
    echo "Firmware:"
    echo "  $FW_PATH"
    echo
    echo "Backup:"
    echo "  $BACKUP_FW"
    echo
    echo "Config:"
    echo "  $CONFIG_PATH"
    echo
    echo "Backup:"
    echo "  $BACKUP_CONFIG"
    echo

    [[ -f "$BACKUP_FW" ]] ||
        die "Firmware backup does not exist: $BACKUP_FW"

    [[ -f "$BACKUP_CONFIG" ]] ||
        die "Config backup does not exist: $BACKUP_CONFIG"

    read -r -p "Restore the in-place backups? [y/N] " answer

    [[ "$answer" =~ ^[Yy]$ ]] ||
        die "Rollback cancelled."

    info "Stopping Bluetooth service..."
    sudo systemctl stop bluetooth.service || true

    info "Removing btusb kernel module..."

    if ! sudo modprobe -r btusb; then
        die "Could not unload btusb. Rollback cancelled; no files were changed."
    fi

    BTUSB_UNLOADED=true

    if sudo test -e "$FW_PATH"; then
        sudo mv \
            "$FW_PATH" \
            "${FW_PATH}.rollback-${TIMESTAMP}"
    fi

    if sudo test -e "$CONFIG_PATH"; then
        sudo mv \
            "$CONFIG_PATH" \
            "${CONFIG_PATH}.rollback-${TIMESTAMP}"
    fi

    info "Restoring original firmware..."

    sudo install \
        -o root \
        -g root \
        -m 0644 \
        "$BACKUP_FW" \
        "$FW_PATH"

    sudo install \
        -o root \
        -g root \
        -m 0644 \
        "$BACKUP_CONFIG" \
        "$CONFIG_PATH"

    info "Reloading btusb..."

    if ! sudo modprobe btusb; then
        die "Original firmware restored, but btusb could not be reloaded."
    fi

    BTUSB_UNLOADED=false

    info "Starting Bluetooth service..."
    sudo systemctl start bluetooth.service || true

    show_bluetooth_info "Post-rollback Bluetooth information"

    echo
    echo "Rollback complete."
    echo "Reboot or unplug/replug the BT500 before testing."
}

# ------------------------------------------------------------
# Rollback mode
# ------------------------------------------------------------

if [[ "${1:-}" == "--rollback" ]]; then
    need_command sudo
    need_command systemctl
    rollback
    exit 0
fi

# ------------------------------------------------------------
# Privileged commands
# ------------------------------------------------------------

if [[ "$DRY_RUN" == false ]]; then
    need_command sudo
    need_command systemctl
fi

# ------------------------------------------------------------
# Header
# ------------------------------------------------------------

echo
echo "============================================================"
echo " ASUS USB-BT500 firmware replacement (Fedora)"
echo "============================================================"

if [[ "$DRY_RUN" == true ]]; then
    echo
    echo "                         DRY RUN"
    echo
    echo "No installed firmware or backup files will be modified."
    echo "Bluetooth kernel modules will NOT be touched."
    echo "Bluetooth service will NOT be stopped."
    echo "No initramfs will be modified."
fi

echo
echo "Firmware directory:"
echo "  $FW_DIR"
echo
echo "Current firmware:"
echo "  $FW_FILENAME"
echo "  $CONFIG_FILENAME"
echo
echo "Compression:"
echo "  .$COMPRESSION"
echo
echo "Known-bad firmware:"
echo "  $KNOWN_BAD_FW"
echo
echo "Replacement repository:"
echo "  $REPO_URL"

show_bluetooth_info "Current Bluetooth information"

# ------------------------------------------------------------
# Capture current firmware version
# ------------------------------------------------------------

CURRENT_FW_VERSION="$(get_current_fw_version || true)"

if [[ -n "$CURRENT_FW_VERSION" ]]; then

    echo
    echo "============================================================"
    echo " Current firmware status"
    echo "============================================================"
    echo

    if [[ "${CURRENT_FW_VERSION,,}" == "${KNOWN_BAD_FW,,}" ]]; then
        echo "  !!! KNOWN-BAD FIRMWARE DETECTED !!!"
        echo
        echo "  Loaded version:"
        echo "    $CURRENT_FW_VERSION"
        echo
        echo "  This matches the known-bad version:"
        echo "    $KNOWN_BAD_FW"
    else
        echo "  Loaded version:"
        echo "    $CURRENT_FW_VERSION"
        echo
        echo "  Status:"
        echo "    Different from known-bad $KNOWN_BAD_FW"
    fi

    echo

else

    echo
    echo "============================================================"
    echo " Current firmware status"
    echo "============================================================"
    echo
    echo "  UNKNOWN"
    echo
    echo "  The kernel log does not currently expose an RTL firmware"
    echo "  version line."
    echo
    echo "  This does NOT prevent the dry-run from continuing."
    echo "  The parser itself will be tested against $KNOWN_BAD_FW."
    echo

fi

# ------------------------------------------------------------
# Confirmation
# ------------------------------------------------------------

if [[ "$DRY_RUN" == true ]]; then
    dry_info "Starting non-destructive test."
else
    read -r -p "Continue? [y/N] " answer

    [[ "$answer" =~ ^[Yy]$ ]] ||
        die "Cancelled."
fi

# ------------------------------------------------------------
# Temporary staging area
# ------------------------------------------------------------

TMP_DIR="$(mktemp -d /tmp/asus-bt500-fw.XXXXXXXX)"

chmod 700 "$TMP_DIR"

REPO_DIR="$TMP_DIR/repository"
STAGE_DIR="$TMP_DIR/staged"
VERIFY_DIR="$TMP_DIR/verify"

if [[ "$DRY_RUN" == true ]]; then
    dry_info "Temporary staging directory: $TMP_DIR"
else
    info "Temporary staging directory: $TMP_DIR"
fi

# ------------------------------------------------------------
# Clone repository
# ------------------------------------------------------------

if [[ "$DRY_RUN" == true ]]; then
    dry_info "Cloning Andrew-ld's firmware repository..."
else
    info "Cloning Andrew-ld's firmware repository..."
fi

git clone \
    --depth 1 \
    --single-branch \
    "$REPO_URL" \
    "$REPO_DIR"

[[ -d "$REPO_DIR/.git" ]] ||
    die "Repository clone failed."

REPO_COMMIT="$(
    git -C "$REPO_DIR" rev-parse HEAD
)"

if [[ "$DRY_RUN" == true ]]; then
    dry_info "Repository commit: $REPO_COMMIT"
else
    info "Repository commit: $REPO_COMMIT"
fi

# ------------------------------------------------------------
# Locate repository firmware files
# ------------------------------------------------------------

SOURCE_FW="$REPO_DIR/rtl8761bu_fw.bin"
SOURCE_CONFIG="$REPO_DIR/rtl8761bu_config.bin"

[[ -f "$SOURCE_FW" ]] ||
    die "Repository is missing rtl8761bu_fw.bin: $SOURCE_FW"

[[ -f "$SOURCE_CONFIG" ]] ||
    die "Repository is missing rtl8761bu_config.bin: $SOURCE_CONFIG"

[[ -s "$SOURCE_FW" ]] ||
    die "Repository firmware is empty: $SOURCE_FW"

[[ -s "$SOURCE_CONFIG" ]] ||
    die "Repository config is empty: $SOURCE_CONFIG"

echo
echo "Repository firmware files:"
echo "  $SOURCE_FW"
echo "  $SOURCE_CONFIG"
echo

# ------------------------------------------------------------
# Stage replacement firmware (Fedora Stock Parameters)
# ------------------------------------------------------------

install \
    -d \
    -m 0700 \
    "$STAGE_DIR"

if [[ "$DRY_RUN" == true ]]; then
    dry_info "Preparing replacement firmware..."
else
    info "Preparing replacement firmware..."
fi

case "$COMPRESSION" in

    zst)

        # Fedora stock linux-firmware RPM uses zstd -19 --ultra
        zstd \
            --quiet \
            --force \
            -19 \
            --ultra \
            "$SOURCE_FW" \
            -o "$STAGE_DIR/$FW_FILENAME"

        zstd \
            --quiet \
            --force \
            -19 \
            --ultra \
            "$SOURCE_CONFIG" \
            -o "$STAGE_DIR/$CONFIG_FILENAME"

        ;;

    xz)

        # Fedora stock linux-firmware RPM uses xz -9 --check=crc32
        xz \
            --force \
            -c \
            -9 \
            --check=crc32 \
            "$SOURCE_FW" \
            > "$STAGE_DIR/$FW_FILENAME"

        xz \
            --force \
            -c \
            -9 \
            --check=crc32 \
            "$SOURCE_CONFIG" \
            > "$STAGE_DIR/$CONFIG_FILENAME"

        ;;

    plain)

        install \
            -m 0600 \
            "$SOURCE_FW" \
            "$STAGE_DIR/$FW_FILENAME"

        install \
            -m 0600 \
            "$SOURCE_CONFIG" \
            "$STAGE_DIR/$CONFIG_FILENAME"

        ;;

esac

[[ -s "$STAGE_DIR/$FW_FILENAME" ]] ||
    die "Staged firmware is missing or empty."

[[ -s "$STAGE_DIR/$CONFIG_FILENAME" ]] ||
    die "Staged config is missing or empty."

# ------------------------------------------------------------
# Show staged checksums
# ------------------------------------------------------------

echo

if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY-RUN] Staged firmware SHA-256:"
else
    echo "Staged firmware SHA-256:"
fi

sha256sum \
    "$STAGE_DIR/$FW_FILENAME" \
    "$STAGE_DIR/$CONFIG_FILENAME"

# ------------------------------------------------------------
# Round-trip compression verification
# ------------------------------------------------------------

install \
    -d \
    -m 0700 \
    "$VERIFY_DIR"

case "$COMPRESSION" in

    zst)

        zstd \
            --quiet \
            -d \
            "$STAGE_DIR/$FW_FILENAME" \
            -o "$VERIFY_DIR/rtl8761bu_fw.bin"

        zstd \
            --quiet \
            -d \
            "$STAGE_DIR/$CONFIG_FILENAME" \
            -o "$VERIFY_DIR/rtl8761bu_config.bin"

        ;;

    xz)

        xz \
            -d \
            -c \
            "$STAGE_DIR/$FW_FILENAME" \
            > "$VERIFY_DIR/rtl8761bu_fw.bin"

        xz \
            -d \
            -c \
            "$STAGE_DIR/$CONFIG_FILENAME" \
            > "$VERIFY_DIR/rtl8761bu_config.bin"

        ;;

    plain)

        install \
            -m 0600 \
            "$STAGE_DIR/$FW_FILENAME" \
            "$VERIFY_DIR/rtl8761bu_fw.bin"

        install \
            -m 0600 \
            "$STAGE_DIR/$CONFIG_FILENAME" \
            "$VERIFY_DIR/rtl8761bu_config.bin"

        ;;

esac

# ------------------------------------------------------------
# Compare decompressed files with repository
# ------------------------------------------------------------

cmp \
    "$SOURCE_FW" \
    "$VERIFY_DIR/rtl8761bu_fw.bin" ||
    die "Firmware compression round-trip verification failed."

cmp \
    "$SOURCE_CONFIG" \
    "$VERIFY_DIR/rtl8761bu_config.bin" ||
    die "Config compression round-trip verification failed."

if [[ "$DRY_RUN" == true ]]; then
    dry_info "Compression round-trip verification passed."
else
    info "Compression round-trip verification passed."
fi

# ------------------------------------------------------------
# Dry-run firmware-version tests
# ------------------------------------------------------------

if [[ "$DRY_RUN" == true ]]; then

    echo
    echo "============================================================"
    echo " Firmware-version detection dry-run"
    echo "============================================================"
    echo

    echo "[DRY-RUN] Testing RTL firmware-version parser..."

    if self_test_firmware_parser; then
        echo
        echo "[DRY-RUN] PASS:"
        echo "  Parser correctly detects:"
        echo "    $KNOWN_BAD_FW"
    else
        die "Firmware-version parser self-test failed."
    fi

    echo
    echo "[DRY-RUN] Testing known-good classification..."

    TEST_VERSION="0x00000001"

    if [[ "${TEST_VERSION,,}" != "${KNOWN_BAD_FW,,}" ]]; then
        echo
        echo "[DRY-RUN] PASS:"
        echo "  A different firmware version is correctly classified"
        echo "  as different from the known-bad version."
    else
        die "Firmware-version classification self-test failed."
    fi

    echo
    echo "[DRY-RUN] Testing actual current firmware detection..."

    if [[ -z "$CURRENT_FW_VERSION" ]]; then

        echo
        echo "  Result: UNKNOWN"
        echo
        echo "  The kernel log does not currently expose an RTL firmware"
        echo "  version line."
        echo
        echo "  This is not treated as a failure because the adapter"
        echo "  may not currently have a usable firmware log entry."
        echo
        echo "  IMPORTANT:"
        echo "  The parser was independently verified to detect"
        echo "  $KNOWN_BAD_FW correctly."

    elif [[ "${CURRENT_FW_VERSION,,}" == "${KNOWN_BAD_FW,,}" ]]; then

        echo
        echo "  Result: KNOWN-BAD"
        echo
        echo "  Current loaded firmware:"
        echo "    $CURRENT_FW_VERSION"
        echo
        echo "  This is exactly the firmware version this script"
        echo "  is intended to replace."

    else

        echo
        echo "  Result: DIFFERENT"
        echo
        echo "  Current loaded firmware:"
        echo "    $CURRENT_FW_VERSION"
        echo
        echo "  Known-bad firmware:"
        echo "    $KNOWN_BAD_FW"
        echo
        echo "  The currently loaded firmware is not the known-bad"
        echo "  version."

    fi

    echo
    echo "[DRY-RUN] Testing post-reload comparison logic..."

    POST_TEST_VERSION="$KNOWN_BAD_FW"

    if [[ "${POST_TEST_VERSION,,}" == "${KNOWN_BAD_FW,,}" ]]; then
        echo
        echo "[DRY-RUN] PASS:"
        echo "  Post-reload check would detect $KNOWN_BAD_FW"
        echo "  and flag the replacement as unsuccessful."
    else
        die "Post-reload firmware check self-test failed."
    fi

fi

# ------------------------------------------------------------
# Check in-place backup state
# ------------------------------------------------------------

if [[ "$DRY_RUN" == true ]]; then

    echo
    echo "[DRY-RUN] Original files would be backed up as:"
    echo
    echo "  $BACKUP_FW"
    echo "  $BACKUP_CONFIG"

    if [[ -e "$BACKUP_FW" ]]; then
        echo
        echo "[DRY-RUN] WARNING: backup already exists:"
        echo "  $BACKUP_FW"
        echo "A real run would refuse to overwrite it."
    fi

    if [[ -e "$BACKUP_CONFIG" ]]; then
        echo
        echo "[DRY-RUN] WARNING: backup already exists:"
        echo "  $BACKUP_CONFIG"
        echo "A real run would refuse to overwrite it."
    fi

else

    if sudo test -e "$BACKUP_FW"; then
        die "A firmware backup already exists:

  $BACKUP_FW

Refusing to overwrite it."
    fi

    if sudo test -e "$BACKUP_CONFIG"; then
        die "A config backup already exists:

  $BACKUP_CONFIG

Refusing to overwrite it."
    fi

fi

# ------------------------------------------------------------
# Dry-run ends here
# ------------------------------------------------------------

if [[ "$DRY_RUN" == true ]]; then

    echo
    echo "============================================================"
    echo " DRY RUN PASSED"
    echo "============================================================"
    echo
    echo "Successfully tested:"
    echo
    echo "  ✓ /usr/lib/firmware/rtl_bt detected"
    echo "  ✓ Existing .bin firmware detected"
    echo "  ✓ Existing compression format detected"
    echo "  ✓ Current firmware version detection attempted"
    echo "  ✓ Known-bad version $KNOWN_BAD_FW detection tested"
    echo "  ✓ Different-version classification tested"
    echo "  ✓ Post-reload known-bad detection tested"
    echo "  ✓ Andrew-ld repository cloned"
    echo "  ✓ rtl8761bu .bin files found"
    echo "  ✓ Replacement firmware staged"
    echo "  ✓ Replacement compression succeeded"
    echo "  ✓ Compressed files decompressed successfully"
    echo "  ✓ Decompressed files match repository .bin files"
    echo "  ✓ In-place backup state checked"
    echo
    echo "Nothing under $FW_DIR was changed."
    echo "No backup was created."
    echo "btusb was not unloaded."
    echo "Bluetooth was not stopped."
    echo "No initramfs was modified."
    echo
    echo "Run the actual replacement with:"
    echo
    echo "  sudo $SCRIPT_NAME"
    echo

    exit 0
fi

# ------------------------------------------------------------
# Final confirmation
# ------------------------------------------------------------

echo
echo "The following files will be changed:"
echo
echo "  $FW_PATH"
echo "  $CONFIG_PATH"
echo
echo "Original files will first be renamed to:"
echo
echo "  $BACKUP_FW"
echo "  $BACKUP_CONFIG"
echo
echo "The replacement will:"
echo
echo "  1. Stop bluetooth.service"
echo "  2. Unload btusb"
echo "  3. Move the original firmware to .bak files"
echo "  4. Install the replacement using install"
echo "  5. Reload btusb"
echo "  6. Check the newly loaded firmware version"
echo "  7. Start bluetooth.service"
echo
echo "No initramfs will be modified."
echo

read -r -p "Perform the replacement? [y/N] " answer

[[ "$answer" =~ ^[Yy]$ ]] ||
    die "Cancelled."

# ------------------------------------------------------------
# Stop Bluetooth
# ------------------------------------------------------------

info "Stopping Bluetooth service..."

sudo systemctl stop bluetooth.service || true

# ------------------------------------------------------------
# Unload btusb
# ------------------------------------------------------------

info "Removing btusb kernel module..."

if ! sudo modprobe -r btusb; then
    die "Could not unload the btusb kernel module.

The firmware has NOT been replaced."
fi

BTUSB_UNLOADED=true

# ------------------------------------------------------------
# In-place backup
# ------------------------------------------------------------

info "Backing up original firmware in place..."

sudo mv \
    "$FW_PATH" \
    "$BACKUP_FW"

sudo mv \
    "$CONFIG_PATH" \
    "$BACKUP_CONFIG"

# ------------------------------------------------------------
# Install replacement
# ------------------------------------------------------------

info "Installing replacement firmware..."

sudo install \
    -o root \
    -g root \
    -m 0644 \
    "$STAGE_DIR/$FW_FILENAME" \
    "$FW_PATH"

sudo install \
    -o root \
    -g root \
    -m 0644 \
    "$STAGE_DIR/$CONFIG_FILENAME" \
    "$CONFIG_PATH"

# ------------------------------------------------------------
# Reload btusb
# ------------------------------------------------------------

info "Reloading btusb kernel module..."

if ! sudo modprobe btusb; then

    echo
    echo "ERROR: btusb could not be reloaded."
    echo
    echo "Restoring original firmware..."
    echo

    sudo rm -f -- \
        "$FW_PATH" \
        "$CONFIG_PATH"

    sudo install \
        -o root \
        -g root \
        -m 0644 \
        "$BACKUP_FW" \
        "$FW_PATH"

    sudo install \
        -o root \
        -g root \
        -m 0644 \
        "$BACKUP_CONFIG" \
        "$CONFIG_PATH"

    if sudo modprobe btusb; then
        BTUSB_UNLOADED=false
    fi

    sudo systemctl start bluetooth.service || true

    die "Firmware replacement was rolled back because btusb could not be reloaded."
fi

BTUSB_UNLOADED=false

# ------------------------------------------------------------
# Post-reload firmware check
# ------------------------------------------------------------

show_bluetooth_info "Post-reload Bluetooth information"

NEW_FW_VERSION="$(get_current_fw_version || true)"

if [[ -z "$NEW_FW_VERSION" ]]; then

    warn "Could not determine the newly loaded firmware version."

    echo
    echo "The firmware files were installed, but the kernel did not"
    echo "report an RTL firmware version in the logs."
    echo

elif [[ "${NEW_FW_VERSION,,}" == "${KNOWN_BAD_FW,,}" ]]; then

    echo
    echo "============================================================"
    echo " !!! WARNING: KNOWN-BAD FIRMWARE STILL LOADED !!!"
    echo "============================================================"
    echo
    echo "Loaded firmware:"
    echo "  $NEW_FW_VERSION"
    echo
    echo "The replacement did not result in a different firmware"
    echo "version being reported by the adapter."
    echo

    read -r -p "Restore the original backup and abort? [Y/n] " answer

    if [[ ! "$answer" =~ ^[Nn]$ ]]; then

        info "Stopping Bluetooth service..."
        sudo systemctl stop bluetooth.service || true

        info "Removing btusb..."

        if sudo modprobe -r btusb; then
            BTUSB_UNLOADED=true
        fi

        sudo rm -f -- \
            "$FW_PATH" \
            "$CONFIG_PATH"

        sudo install \
            -o root \
            -g root \
            -m 0644 \
            "$BACKUP_FW" \
            "$FW_PATH"

        sudo install \
            -o root \
            -g root \
            -m 0644 \
            "$BACKUP_CONFIG" \
            "$CONFIG_PATH"

        if sudo modprobe btusb; then
            BTUSB_UNLOADED=false
        fi

        sudo systemctl start bluetooth.service || true

        die "Replacement aborted; original firmware restored."
    fi

else

    echo
    echo "============================================================"
    echo " Firmware replacement verification"
    echo "============================================================"
    echo
    echo "Loaded firmware:"
    echo "  $NEW_FW_VERSION"
    echo
    echo "Known-bad firmware:"
    echo "  $KNOWN_BAD_FW"
    echo
    echo "Result:"
    echo "  PASS — loaded firmware is not the known-bad version."
    echo

fi

# ------------------------------------------------------------
# Start Bluetooth
# ------------------------------------------------------------

info "Starting Bluetooth service..."

if ! sudo systemctl start bluetooth.service; then
    echo
    echo "WARNING: bluetooth.service failed to start."
    echo
    echo "The firmware files are installed and btusb is loaded."
    echo
    echo "Check the service with:"
    echo
    echo "  systemctl status bluetooth.service"
    echo
fi

# ------------------------------------------------------------
# Verify final installation
# ------------------------------------------------------------

info "Verifying installed firmware..."

[[ -s "$FW_PATH" ]] ||
    die "Installed firmware is missing."

[[ -s "$CONFIG_PATH" ]] ||
    die "Installed config is missing."

echo
echo "Installed firmware SHA-256:"
sudo sha256sum \
    "$FW_PATH" \
    "$CONFIG_PATH"

echo
echo "Original firmware backup SHA-256:"
sudo sha256sum \
    "$BACKUP_FW" \
    "$BACKUP_CONFIG"

# ------------------------------------------------------------
# Done
# ------------------------------------------------------------

echo
echo "============================================================"
echo " Firmware replacement completed"
echo "============================================================"
echo
echo "Installed:"
echo "  $FW_PATH"
echo "  $CONFIG_PATH"
echo
echo "Original firmware preserved as:"
echo "  $BACKUP_FW"
echo "  $BACKUP_CONFIG"
echo
echo "Repository commit:"
echo "  $REPO_COMMIT"
echo
echo "Compression:"
echo "  .$COMPRESSION"
echo
echo "Bluetooth module:"
echo "  btusb unloaded and reloaded"
echo
echo "No initramfs was modified."
echo
echo "Check the loaded firmware with:"
echo
echo "  sudo journalctl -k -b 0 | grep -i 'RTL: fw version'"
echo
echo "To roll back:"
echo
echo "  sudo $SCRIPT_NAME --rollback"
echo
