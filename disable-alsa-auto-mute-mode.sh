#!/usr/bin/sh

if test ! -f "$(command -v amixer)"
then
    echo "amixer: command not found"
    exit 1
fi

AUTO_MUTE_MODE=$(amixer --card 0 get "Auto-Mute Mode" | grep "Item0" | awk '{print $2}' | tr -d \')

if test "$AUTO_MUTE_MODE" = "Disabled"
then
    echo "Auto-Mute Mode is already disabled."
    exit 0
fi

echo "Disabling Auto-Mute Mode..."
amixer --card 0 sset "Auto-Mute Mode" Disabled

echo "Saving ALSA settings..."
sudo alsactl store
