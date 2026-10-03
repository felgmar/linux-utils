#!/bin/bash
set -euo pipefail

CURRENT_USER="$(whoami)"
CURRENT_DIR="$(dirname "$(readlink -f "$0")")"

if [ "$CURRENT_USER" != "root" ]
then
  echo "This script must be run as root."
  exit 1
fi

if [ -z "$1" ]
then
  echo "Usage: sudo $0 <offending-program>"
  exit 1
fi

if [ ! -x "$(command -v ausearch)" ] || [ ! -x "$(command -v audit2allow)" ] || [ ! -x "$(command -v semodule)" ]
then
  echo "This script requires the 'audit' and 'policycoreutils' packages to be installed."
  exit 1
fi


if [ -d "$CURRENT_DIR/selinux-modules" ]
then
    echo "[*] Using existing directory '$CURRENT_DIR/selinux-modules' for policy packages."
else
    echo "[*] Created directory '$CURRENT_DIR/selinux-modules' for policy packages."
    mkdir selinux-modules
fi

cd selinux-modules

if [ -f "$1.pp" ]
then
  echo "[!] Policy package '$1.pp' already exists."
  exit 1
else
    echo "[*] Searching AVC denials for '$1' and generating module '$1'..."
    ausearch -c "$1" --raw | audit2allow -M "$1" || exit $?
fi

echo "[*] Installing policy package..."
semodule -i "${1}.pp" && echo "[+] Success! Module '$1' installed and active." || echo "[!] Failed to install module '$1'."

cd "$CURRENT_DIR"

exit $?
