#!/usr/bin/env python3
import subprocess
import sys

def parse_auto_mute_mode(output: str) -> str | None:
    for line in output.splitlines():
        label, separator, value = line.strip().partition(":")

        if not label == "Item0" or not separator:
            continue

        value = value.strip()

        if value.startswith("'") and value.endswith("'"):
            value = value.strip("'")

        return value

    return None

def main() -> int:
    process = subprocess.run(["amixer", "--card", "0", "get", "Auto-Mute Mode"],
                             capture_output=True, text=True)
    auto_mute_mode = parse_auto_mute_mode(process.stdout)

    if auto_mute_mode is None:
        print("Could not determine Auto-Mute Mode.", file=sys.stderr)
        return 1

    if auto_mute_mode == "Disabled":
        print("Auto-Mute Mode is already disabled.")
        return 1

    print("Disabling Auto-Mute Mode...")
    subprocess.run(["amixer", "--card", "0", "set", "Auto-Mute Mode", "Disabled"], check=True).check_returncode()

    print("Saving ALSA settings...")
    subprocess.run(["sudo", "alsactl", "store"], check=True)
    return 0

if __name__ == "__main__":
    try:
        main()
    except:
        raise
