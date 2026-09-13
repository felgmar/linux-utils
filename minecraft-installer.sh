#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Minecraft Launcher installer
#
# Downloads the official Minecraft Launcher from Mojang and
# installs it under /opt/minecraft-launcher along with its icon.
#
# Installed files:
#
#   /opt/minecraft-launcher/
#   /opt/minecraft-launcher/minecraft-launcher.svg
#   /usr/local/bin/minecraft-launcher
#   /usr/local/share/applications/minecraft-launcher.desktop
#
# ============================================================

SOURCE_URL="https://launcher.mojang.com/download/Minecraft.tar.gz"
ICON_URL="https://raw.githubusercontent.com/flathub/com.mojang.Minecraft/master/com.mojang.Minecraft.svg"

INSTALL_DIR="/opt/minecraft-launcher"
ICON_FILE="${INSTALL_DIR}/minecraft-launcher.svg"
BIN_DIR="/usr/local/bin"
BIN_FILE="${BIN_DIR}/minecraft-launcher"

DESKTOP_DIR="/usr/local/share/applications"
DESKTOP_FILE="${DESKTOP_DIR}/minecraft-launcher.desktop"

TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT

# ------------------------------------------------------------
# Check root
# ------------------------------------------------------------

if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: This installer must be run as root."
    echo
    echo "Run:"
    echo "  sudo $0"
    exit 1
fi

# ------------------------------------------------------------
# Check dependencies
# ------------------------------------------------------------

for command in curl tar find install; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "ERROR: Required command '$command' was not found."
        exit 1
    fi
done

# ------------------------------------------------------------
# Download launcher archive
# ------------------------------------------------------------

echo "==> Downloading official Minecraft Launcher..."
echo "    $SOURCE_URL"

ARCHIVE="${TMP_DIR}/Minecraft.tar.gz"

curl \
    --fail \
    --location \
    --show-error \
    --progress-bar \
    --output "$ARCHIVE" \
    "$SOURCE_URL"

# ------------------------------------------------------------
# Inspect archive
# ------------------------------------------------------------

echo
echo "==> Archive contents:"
tar -tzf "$ARCHIVE" | sed -n '1,30p'
echo

# ------------------------------------------------------------
# Extract
# ------------------------------------------------------------

echo "==> Extracting launcher..."

EXTRACT_DIR="${TMP_DIR}/extracted"

mkdir -p "$EXTRACT_DIR"

tar \
    --extract \
    --gzip \
    --file "$ARCHIVE" \
    --directory "$EXTRACT_DIR"

# ------------------------------------------------------------
# Locate launcher executable
# ------------------------------------------------------------

LAUNCHER="$(find "$EXTRACT_DIR" -type f -name minecraft-launcher -print -quit)"

if [[ -z "$LAUNCHER" ]]; then
    echo "ERROR: Could not find minecraft-launcher in the archive."
    exit 1
fi

echo "    Found launcher: $LAUNCHER"

LAUNCHER_ROOT="$(dirname "$LAUNCHER")"

# ------------------------------------------------------------
# Install launcher
# ------------------------------------------------------------

echo
echo "==> Installing to ${INSTALL_DIR}..."

rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# Copy everything from the official archive
cp -a "${LAUNCHER_ROOT}/." "$INSTALL_DIR/"

# Ensure the launcher binary is executable
chmod 755 "${INSTALL_DIR}/minecraft-launcher"

# ------------------------------------------------------------
# Download icon directly to installation directory
# ------------------------------------------------------------

echo "==> Downloading icon to ${ICON_FILE}..."

curl \
    --fail \
    --location \
    --show-error \
    --output "$ICON_FILE" \
    "$ICON_URL"

chmod 644 "$ICON_FILE"

# ------------------------------------------------------------
# Create launcher wrapper
# ------------------------------------------------------------

echo "==> Creating ${BIN_FILE}..."

mkdir -p "$BIN_DIR"

cat > "$BIN_FILE" <<EOF
#!/bin/sh

__GLX_VENDOR_LIBRARY_NAME=nvidia exec "${INSTALL_DIR}/minecraft-launcher" "\$@"

EOF

chmod 755 "$BIN_FILE"

# ------------------------------------------------------------
# Create desktop entry
# ------------------------------------------------------------

echo "==> Creating desktop entry..."

mkdir -p "$DESKTOP_DIR"

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=Minecraft
Comment=Official Minecraft Launcher
Exec=${BIN_FILE} %U
Icon=${ICON_FILE}
Terminal=false
Type=Application
Categories=Game;
StartupNotify=true
EOF

chmod 644 "$DESKTOP_FILE"

# ------------------------------------------------------------
# Update desktop database if available
# ------------------------------------------------------------

if command -v update-desktop-database >/dev/null 2>&1; then
    echo "==> Updating desktop database..."
    update-desktop-database "$DESKTOP_DIR" || true
fi

# ------------------------------------------------------------
# Finished
# ------------------------------------------------------------

if [ $? -ne 0 ]
then
    echo "An error has occurred. Exit code $?."
fi

echo
echo "============================================================"
echo "Minecraft Launcher installed successfully."
echo "============================================================"
echo
