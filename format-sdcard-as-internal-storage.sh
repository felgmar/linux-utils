#!/bin/sh
set -e

[ ! -x "/usr/bin/adb" ] && \
    echo "ERROR: adb was not found" && \
    exit 1

disk=`adb shell sm list-disks`

echo "Setting set-force-adoptable to 'on'..."
adb shell sm set-force-adoptable on

echo "Partitioning $disk..."
adb shell sm partition $disk private

uuid="`adb shell sm list-volumes | grep "private" | cut -d " " -f 3 | head -n 1`"

echo "Moving primary storage to $uuid..."
adb shell pm move-primary-storage $uuid
