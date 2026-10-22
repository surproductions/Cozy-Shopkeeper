#!/usr/bin/env python3
"""Reads `xcrun simctl list devices available -j` from stdin and prints the UDID
of the newest available iPhone simulator (prefers non-Pro, non-Max models)."""
import json
import re
import sys

data = json.load(sys.stdin)
candidates = []
for runtime, devices in data.get("devices", {}).items():
    m = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not m:
        continue
    version = (int(m.group(1)), int(m.group(2)))
    for d in devices:
        name = d.get("name", "")
        if d.get("isAvailable") and name.startswith("iPhone"):
            plain = 0 if ("Pro" in name or "Max" in name or "Plus" in name) else 1
            candidates.append((version, plain, name, d["udid"]))
if not candidates:
    sys.exit("No available iPhone simulator found")
candidates.sort()
print(candidates[-1][3])
