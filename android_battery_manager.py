import math
from typing import Any

MAX_BATTERY_CAPACITY_TYPICAL: int = int(input("Enter the maximum battery capacity by design (in mAh): "))
def get_stats() -> dict[str, Any]:
    import subprocess
    COMMAND_STRING: str = "adb shell dumpsys battery"
    output = subprocess.check_output(COMMAND_STRING, shell=True).decode()
    stats: dict[str, Any] = {}

    for line in output.splitlines():
        if ':' in line:
            key, value = line.split(':', 1)
            stats[key.strip()] = value.strip()
    return stats

BATTERY_STATS: dict[str, Any] = get_stats()
BATTERY_CHARGE_COUNTER: int = math.trunc(int(BATTERY_STATS["Charge counter"]) / 10)
BATTERY_LEVEL_PERCENTAGE: int = int(BATTERY_STATS["level"])
MAX_BATTERY_CAPACITY_LEFT = math.trunc((BATTERY_CHARGE_COUNTER) / MAX_BATTERY_CAPACITY_TYPICAL)

print(f"""Battery status:
-> Current battery level: {BATTERY_LEVEL_PERCENTAGE} %
-> Current charge counter: {BATTERY_CHARGE_COUNTER}
-> Maximum capacity by design: {MAX_BATTERY_CAPACITY_TYPICAL} mAh
-> Current battery health: {MAX_BATTERY_CAPACITY_LEFT} %""")
