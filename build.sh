#!/bin/bash
#
# build.sh — Compile, signe et lance DNSTuner.
#
set -euo pipefail
cd "$(dirname "$0")"

APP="DNSTuner.app"
BIN="$APP/Contents/MacOS/DNSTuner"

# L'Info.plist (icône, identifiant du bundle) est versionné : s'il manque, on le
# restaure depuis git plutôt que de produire un bundle sans identité.
if [ ! -f "$APP/Contents/Info.plist" ]; then
    echo "▸ Info.plist manquant, restauration depuis git…"
    git checkout -- "$APP/Contents/Info.plist" 2>/dev/null \
        || { echo "✗ Info.plist introuvable (git checkout a échoué)."; exit 1; }
fi

echo "▸ Compilation (cible macOS 26.0 → compatible 26 et 27)…"
mkdir -p "$APP/Contents/MacOS"
swiftc -O -parse-as-library -target arm64-apple-macos26.0 \
    Sources/*.swift \
    Sources/Core/*.swift \
    Sources/Features/*.swift \
    Sources/UI/*.swift \
    Sources/Views/*.swift \
    Sources/App/*.swift \
    -o "$BIN"

echo "▸ Icône…"
if [ -f "logo.png" ] && [ ! -f "AppIcon.icns" ]; then
    ICONSET="AppIcon.iconset"; rm -rf "$ICONSET"; mkdir -p "$ICONSET"
    for s in 16 32 128 256 512; do
        sips -z $s $s logo.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null 2>&1
        sips -z $((s*2)) $((s*2)) logo.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null 2>&1
    done
    iconutil -c icns "$ICONSET" -o AppIcon.icns && rm -rf "$ICONSET"
fi
[ -f "AppIcon.icns" ] && { mkdir -p "$APP/Contents/Resources"; cp AppIcon.icns "$APP/Contents/Resources/"; }

echo "▸ Signature ad-hoc…"
codesign --force --sign - "$APP" >/dev/null 2>&1

echo "▸ Lancement…"
pkill -x DNSTuner 2>/dev/null || true
open "$APP"
echo "✓ DNSTuner lancé."
