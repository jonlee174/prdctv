#!/bin/bash
# Captures iPhone screenshots of the demo data and composes the App Store header and search results art.
set -euo pipefail

cd "$(dirname "$0")/.."
DEVICE="iPhone 17 Pro Max"
BUNDLE_ID=com.jonathanlee.prdctv
SHOTS=build/store-art/shots
rm -rf build/store-art
mkdir -p "$SHOTS"

xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null
xcrun simctl ui "$DEVICE" appearance light
xcrun simctl status_bar "$DEVICE" override --time 9:41 --dataNetwork wifi --wifiBars 3 \
    --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
xcrun simctl install "$DEVICE" build/Build/Products/Debug-iphonesimulator/prdctv.app

shot() {
    xcrun simctl spawn "$DEVICE" defaults write $BUNDLE_ID laneGrouping "$2"
    xcrun simctl launch --terminate-running-process "$DEVICE" $BUNDLE_ID --demo --tab "$3" >/dev/null
    /bin/sleep 4
    xcrun simctl io "$DEVICE" screenshot "$SHOTS/$1.png" >/dev/null 2>&1
}
shot board none board
shot tags tag board
shot calendar none calendar
xcrun simctl spawn "$DEVICE" defaults delete $BUNDLE_ID laneGrouping || true
xcrun simctl status_bar "$DEVICE" clear

python3 scripts/store_art.py "$SHOTS" build/store-art
