#!/bin/bash
# Captures App Store screenshots of the demo data for iPhone, iPad and Mac.
set -euo pipefail

cd "$(dirname "$0")/.."
OUT=build/screenshots
BUNDLE_ID=com.jonathanlee.prdctv
IOS_APP=build/Build/Products/Debug-iphonesimulator/prdctv.app
MAC_APP=build/Build/Products/Debug/prdctv.app
# 6.9 inch iPhone and 13 inch iPad. The 6.5 inch iPhone set is scaled from the 6.9 inch one.
DEVICES=("iPhone 17 Pro Max" "iPad Pro 13-inch (M5)")
TABS=(board calendar stats)

rm -rf "$OUT"
mkdir -p "$OUT/iphone-6.9" "$OUT/iphone-6.5" "$OUT/ipad-13" "$OUT/mac"

xcodebuild -project prdctv.xcodeproj -derivedDataPath build -scheme prdctviOS \
    -destination 'generic/platform=iOS Simulator' -quiet build
xcodebuild -project prdctv.xcodeproj -derivedDataPath build -scheme prdctv \
    -destination 'platform=macOS,arch=arm64' -allowProvisioningUpdates -quiet build

for device in "${DEVICES[@]}"; do
    folder=$([[ $device == iPad* ]] && echo ipad-13 || echo iphone-6.9)
    xcrun simctl boot "$device" 2>/dev/null || true
    xcrun simctl bootstatus "$device" -b >/dev/null
    xcrun simctl ui "$device" appearance light
    xcrun simctl status_bar "$device" override --time 9:41 --dataNetwork wifi --wifiBars 3 \
        --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
    xcrun simctl install "$device" "$IOS_APP"
    for tab in "${TABS[@]}"; do
        xcrun simctl launch --terminate-running-process "$device" "$BUNDLE_ID" --demo --tab "$tab" >/dev/null
        /bin/sleep 4
        xcrun simctl io "$device" screenshot "$OUT/$folder/$tab.png" >/dev/null 2>&1
        echo "$OUT/$folder/$tab.png"
    done
    xcrun simctl status_bar "$device" clear
done

# 1284x2778 for the 6.5 inch slot. Scaling to that width leaves 12 extra rows, trimmed evenly.
python3 - "$OUT" <<'EOF'
import sys
from pathlib import Path
from PIL import Image
out = Path(sys.argv[1])
for src in sorted((out / "iphone-6.9").glob("*.png")):
    img = Image.open(src).convert("RGB")
    scaled = img.resize((1284, round(img.height * 1284 / img.width)), Image.LANCZOS)
    top = (scaled.height - 2778) // 2
    scaled.crop((0, top, 1284, top + 2778)).save(out / "iphone-6.5" / src.name)
    print(out / "iphone-6.5" / src.name)
EOF

# Mac shots at 2560x1600, a 1280x800 window at Retina scale, in light mode.
MAC_SHOTS=("board none board" "tags tag board" "calendar none calendar")
for shot in "${MAC_SHOTS[@]}"; do
    read -r name lanes mode <<<"$shot"
    file="$OUT/mac/$name.png"
    for attempt in 1 2 3; do
        pkill -x prdctv 2>/dev/null || true
        /bin/sleep 2
        # Values joined with "=", since a separate word opens the app with no window.
        open "$MAC_APP" --args --demo --appearance=light --lanes="$lanes" --mode="$mode" --window-size=1280x800
        # Wait until the window has its final size, then let the open animation finish.
        window=""
        for _ in $(seq 1 15); do
            /bin/sleep 1
            read -r id width height <<<"$(swift scripts/window_id.swift 2>/dev/null || true)"
            if [[ ${width:-0} == 1280 && ${height:-0} == 800 ]]; then window=$id; break; fi
        done
        [[ -n $window ]] || continue
        /bin/sleep 3
        screencapture -x -o -l"$window" "$file"
        size=$(sips -g pixelWidth -g pixelHeight "$file" | awk '/pixel/ {printf "%s ", $2}')
        [[ $size == "2560 1600 " ]] && break
        rm -f "$file"
    done
    [[ -f $file ]] || { echo "Couldn't capture $file at 2560x1600" >&2; exit 1; }
    echo "$file"
done
pkill -x prdctv 2>/dev/null || true
/bin/sleep 2
open "$MAC_APP"

# The window's rounded corners come out transparent. Fill them so the images have no alpha.
python3 - "$OUT/mac" <<'EOF'
import sys
from pathlib import Path
from PIL import Image
for path in sorted(Path(sys.argv[1]).glob("*.png")):
    img = Image.open(path).convert("RGBA")
    flat = Image.new("RGB", img.size, (236, 236, 236))
    flat.paste(img, mask=img.split()[3])
    flat.save(path)
EOF

for f in "$OUT"/*/*.png; do
    echo "$f $(sips -g pixelWidth -g pixelHeight "$f" | awk '/pixel/ {printf "%s ", $2}')"
done
