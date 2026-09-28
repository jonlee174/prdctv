#!/bin/bash
# Checks the Mac App Store package has its installer signature and a full app icon.
# Usage: check_mac_package.sh build/dist/prdctv.pkg, or --app path/to/prdctv.app to check only the icon.
set -euo pipefail

fail() { echo "error: $*" >&2; exit 1; }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

if [[ ${1:-} == --app ]]; then
    app=$2
else
    pkg=$1
    [[ -f $pkg ]] || fail "$pkg doesn't exist"
    pkgutil --check-signature "$pkg" | grep -q "3rd Party Mac Developer Installer" \
        || fail "$pkg isn't signed with the Mac installer certificate"
    pkgutil --expand-full "$pkg" "$work/pkg" >/dev/null
    app=$(find "$work/pkg" -maxdepth 4 -name prdctv.app -type d | head -1)
    [[ -n $app ]] || fail "no prdctv.app inside $pkg"
fi

# The icon file named in Info.plist must exist.
icon=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" "$app/Contents/Info.plist" 2>/dev/null) \
    || fail "Info.plist has no CFBundleIconFile"
icns="$app/Contents/Resources/${icon%.icns}.icns"
[[ -f $icns ]] || fail "$(basename "$icns") is missing from the app"

# Every Mac icon size must be in the icns. Transporter and the App Store read the 1024 pixel one.
iconutil -c iconset -o "$work/AppIcon.iconset" "$icns" || fail "$(basename "$icns") can't be read"
for size in 16 32 128 256 512; do
    for name in "icon_${size}x${size}.png" "icon_${size}x${size}@2x.png"; do
        [[ -f $work/AppIcon.iconset/$name ]] || fail "the app icon is missing $name"
    done
done
width=$(sips -g pixelWidth "$work/AppIcon.iconset/icon_512x512@2x.png" | awk '/pixelWidth/ {print $2}')
[[ $width == 1024 ]] || fail "the largest app icon is ${width}px wide, not 1024px"

echo "App icon present with every size up to 1024px"
