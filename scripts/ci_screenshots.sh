#!/bin/bash
# Captures App Store screenshots on the 6.9" iPhone simulator (1320 × 2868) using the
# Debug-only showcase mode. Output: build/screenshots/*.png
set -euo pipefail

DEVICE_ID=$(xcrun simctl list devices available -j | python3 scripts/ci_pick_simulator.py --prefer "Pro Max")
echo "Screenshot device: $DEVICE_ID"
xcodebuild build -project CozyShopkeeper.xcodeproj -scheme CozyShopkeeper -configuration Debug \
  -destination "id=$DEVICE_ID" -derivedDataPath build/ShotsDD CODE_SIGNING_ALLOWED=NO -quiet
APP=build/ShotsDD/Build/Products/Debug-iphonesimulator/CozyShopkeeper.app
BUNDLE=com.surproductions.cozyshopkeeper

xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE_ID" -b
xcrun simctl ui "$DEVICE_ID" appearance light || true
xcrun simctl status_bar "$DEVICE_ID" override --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
xcrun simctl install "$DEVICE_ID" "$APP"
mkdir -p build/screenshots

shot() {
  local name=$1; shift
  xcrun simctl terminate "$DEVICE_ID" "$BUNDLE" 2>/dev/null || true
  xcrun simctl launch "$DEVICE_ID" "$BUNDLE" -ui-screenshots "$@" >/dev/null
  sleep 6
  xcrun simctl io "$DEVICE_ID" screenshot "build/screenshots/$name.png"
  echo "captured $name"
}

shot 01-shop
shot 02-stockroom -screen stockroom
shot 03-decor -screen decor
shot 04-journal -screen journal
shot 05-goals -screen goals
shot 06-upgrades -screen upgrades
shot 07-map -screen map
sips -g pixelWidth -g pixelHeight build/screenshots/01-shop.png
