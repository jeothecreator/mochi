#!/bin/bash
# Builds a release Mochi.app into ./build (ad-hoc signed, runs locally).
# Registers the mochi:// URL scheme on first launch (used by the terminal/git hooks).
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${MOCHI_VERSION:-1.0.0}"
ARCHS=(--arch arm64 --arch x86_64)   # universal: Apple Silicon + Intel

echo "▶ Compiling Mochi $VERSION (release, universal)…"
swift build -c release "${ARCHS[@]}"
BIN="$(swift build -c release "${ARCHS[@]}" --show-bin-path)/Mochi"

APP="build/Mochi.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Mochi"

echo "▶ Drawing the pixel icon…"
ICONSET="$(mktemp -d)/Mochi.iconset"
"$BIN" --render-icon "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/Mochi.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Mochi</string>
    <key>CFBundleDisplayName</key><string>Mochi</string>
    <key>CFBundleIdentifier</key><string>com.mochi.desktoppet</string>
    <key>CFBundleExecutable</key><string>Mochi</string>
    <key>CFBundleIconFile</key><string>Mochi</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>LSApplicationCategoryType</key><string>public.app-category.lifestyle</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>A cozy pixel desktop pet.</string>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key><string>com.mochi.desktoppet</string>
            <key>CFBundleURLSchemes</key><array><string>mochi</string></array>
        </dict>
    </array>
</dict>
</plist>
PLIST

source scripts/signing.sh
IDENTITY="$(mochi_identity)"
if [[ -n "$IDENTITY" ]]; then
    echo "▶ Signing with $IDENTITY (hardened runtime)…"
else
    echo "▶ Signing (ad-hoc — no Developer ID certificate found; see docs/SIGNING.md)…"
fi
mochi_sign "$APP" 2>&1 | grep -v "replacing existing signature" || true
codesign --verify --strict "$APP"

echo "✔ Built $APP"
echo "  Run it:      open $APP"
echo "  Install it:  cp -R $APP /Applications/"
