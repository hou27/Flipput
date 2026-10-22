#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="$PWD/dist/Flipput.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$PWD/.build/module-cache"
xcrun swiftc -target "$(uname -m)-apple-macosx13.0" -swift-version 5 -O -module-cache-path "$PWD/.build/module-cache" Sources/*.swift -o "$APP/Contents/MacOS/Flipput" -framework AppKit -framework Carbon -framework ApplicationServices
xcrun swiftc -swift-version 5 -module-cache-path "$PWD/.build/module-cache" Scripts/make_icon.swift -o .build/make-icon
rm -rf .build/AppIcon.iconset
.build/make-icon .build/AppIcon.iconset
iconutil -c icns .build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
echo "Built: $APP"
