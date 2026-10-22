#!/usr/bin/env python3
"""Reads `xcrun simctl list devices available -j` from stdin and prints the UDID of an
iPhone simulator on the newest iOS runtime. `--prefer "Pro Max"` picks the largest
(6.9") model for App Store screenshots; otherwise a standard-size model is preferred."""
import json
import re
import sys

prefer = sys.argv[sys.argv.index("--prefer") + 1] if "--prefer" in sys.argv else None
data = json.load(sys.stdin)
candidates = []
for runtime, devices in data.get("devices", {}).items():
    m = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not m:
        continue
    version = (int(m.group(1)), int(m.group(2)))
    for d in devices:
        name = d.get("name", "")
        if not (d.get("isAvailable") and name.startswith("iPhone")):
            continue
        if prefer:
            score = 1 if prefer in name else 0
        else:
            score = 0 if any(k in name for k in ("Pro", "Max", "Plus")) else 1
        number = int((re.search(r"iPhone (\d+)", name) or [0, 0])[1])
        candidates.append((score, version, number, name, d["udid"]))
if not candidates:
    sys.exit("No available iPhone simulator found")
candidates.sort()
print(candidates[-1][4])
