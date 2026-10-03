#!/bin/sh

SOURCE_URL="https://launcher.mojang.com/download/Minecraft.tar.gz"
ICON_URL="https://raw.githubusercontent.com/flathub/com.mojang.Minecraft/master/com.mojang.Minecraft.svg"

CACHE_DIR="${XDG_CACHE_HOME:-${HOME:-/root}/.cache}/minecraft-launcher"
CACHE_ARCHIVE="${CACHE_DIR}/Minecraft.tar.gz"
CACHE_ICON="${CACHE_DIR}/minecraft-launcher.svg"

INSTALL_DIR="/opt/minecraft-launcher"
ICON_FILE="${INSTALL_DIR}/minecraft-launcher.svg"
BIN_DIR="/usr/local/bin"
BIN_FILE="${BIN_DIR}/minecraft-launcher"
DESKTOP_DIR="/usr/local/share/applications"
DESKTOP_FILE="${DESKTOP_DIR}/minecraft-launcher.desktop"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

if test "$(whoami)" != "root"
then
    echo "ERROR: Run this script as root." >&2
    exit 1
fi

for cmd in curl tar find; do
    if ! command -v "$cmd" >/dev/null 2>&1
then
        echo "ERROR: Required command not found: $cmd" >&2
        exit 1
    fi
done

mkdir -p "$CACHE_DIR"

if [ ! -f "$CACHE_ARCHIVE" ]
then
    echo "[*] Downloading tarball..."
    curl --fail --location --progress-bar --show-error --output "$CACHE_ARCHIVE" "$SOURCE_URL"
else
    echo "[*] Checking tarball for updates..."
    curl --fail --location --progress-bar --show-error --output "$CACHE_ARCHIVE" --time-cond "$CACHE_ARCHIVE" "$SOURCE_URL"
fi

if [ ! -x "${INSTALL_DIR}/minecraft-launcher" ]
then
    echo "[*] Extracting tarball..."
    EXTRACT_DIR="${TMP_DIR}/extracted"
    mkdir -p "$EXTRACT_DIR"
    tar -xzf "$CACHE_ARCHIVE" -C "$EXTRACT_DIR"

    LAUNCHER="$(find "$EXTRACT_DIR" -type f -name minecraft-launcher -print -quit)"
    if [ -z "$LAUNCHER" ]
    then
        echo "ERROR: Could not find minecraft-launcher in the archive." >&2
        exit 1
    fi

    echo "[*] Installing files..."
    rm -rf "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    cp -a "$(dirname "$LAUNCHER")/." "$INSTALL_DIR/"
    chmod 755 "${INSTALL_DIR}/minecraft-launcher"
fi

if [ ! -f "$CACHE_ICON" ]
then
    echo "[*] Downloading icon..."
    curl --fail --location --progress-bar --show-error --output "$CACHE_ICON" "$ICON_URL"
else
    echo "[*] Checking icon for updates..."
    curl --fail --location --progress-bar --show-error --output "$CACHE_ICON" --time-cond "$CACHE_ICON" "$ICON_URL"
fi

if [ ! -f "$ICON_FILE" ] || [ "$CACHE_ICON" -nt "$ICON_FILE" ]
then
    echo "[*] Updating icon..."
    cp -f "$CACHE_ICON" "$ICON_FILE"
    chmod 644 "$ICON_FILE"
fi

if [ ! -f "$BIN_FILE" ] || [ "$INSTALL_DIR/minecraft-launcher" -nt "$BIN_FILE" ]
then
    echo "[*] Updating launcher wrapper..."
    mkdir -p "$BIN_DIR"
    cat > "$BIN_FILE" <<'EOF'
#!/bin/sh
export __GLX_VENDOR_LIBRARY_NAME=nvidia
exec "/opt/minecraft-launcher/minecraft-launcher" "$@"
EOF
    chmod 755 "$BIN_FILE"
fi

if [ ! -f "$DESKTOP_FILE" ] || [ "$BIN_FILE" -nt "$DESKTOP_FILE" ] || [ "$ICON_FILE" -nt "$DESKTOP_FILE" ]
then
    echo "[*] Updating desktop entry..."
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
fi

if command -v update-desktop-database >/dev/null 2>&1
then
    echo "[*] Updating desktop database..."
    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
fi
