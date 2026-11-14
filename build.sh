#!/bin/bash
#
# build.sh : Compile, signe et lance DNSTuner.
#
set -euo pipefail
cd "$(dirname "$0")"

APP="DNSTuner.app"
BIN="$APP/Contents/MacOS/DNSTuner"

# L'Info.plist (icone, identifiant du bundle) est genere s'il manque : le
# bundle n'est pas conserve dans le parc, seul ce script le reconstruit.
if [ ! -f "$APP/Contents/Info.plist" ]; then
    echo "▸ Info.plist manquant, generation…"
    mkdir -p "$APP/Contents"
    cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>DNSTuner</string>
    <key>CFBundleIdentifier</key><string>Rodolphe.DNSTuner</string>
    <key>CFBundleName</key><string>DNSTuner</string>
    <key>CFBundleDisplayName</key><string>DNSTuner</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>26.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
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

# Langues hors français et anglais : Langues/<code>.json (Outils/Parc/LanguesMac.py).
echo "▸ Langues…"
mkdir -p "$APP/Contents/Resources/Langues"
rsync -a --delete Langues/ "$APP/Contents/Resources/Langues/"

echo "▸ Signature ad-hoc…"
codesign --force --sign - "$APP" >/dev/null 2>&1

echo "▸ Lancement…"
pkill -x DNSTuner 2>/dev/null || true
open "$APP"
echo "✓ DNSTuner lancé."
