#!/bin/bash
# Packages build/Mochi.app into a drag-to-Applications DMG: build/Mochi-<version>.dmg
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${MOCHI_VERSION:-1.0.0}"
export MOCHI_VERSION="$VERSION"
./scripts/build-app.sh
source scripts/signing.sh

NOTARIZE=0
if mochi_can_notarize; then
    NOTARIZE=1
    echo "▶ Notarizing the app…"
    mochi_notarize build/Mochi.app
fi

STAGE="$(mktemp -d)/Mochi"
mkdir -p "$STAGE"
cp -R build/Mochi.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
if [[ $NOTARIZE == 0 ]]; then
cat > "$STAGE/First launch — read me.txt" <<'TXT'
Mochi — aesthetic pixel pets for your Mac 🍡

1. Drag Mochi into the Applications folder.
2. Open it. macOS will say it can't verify the developer
   (Mochi is free and not notarized by Apple).
3. Open System Settings → Privacy & Security, scroll down,
   and click "Open Anyway" next to Mochi. You only do this once.

   Terminal alternative:
   xattr -dr com.apple.quarantine /Applications/Mochi.app

Mochi lives in your menu bar (no Dock icon). Left-click the pet to add a
to-do, right-click it for everything else. Fully offline — nothing leaves your Mac.
TXT
fi

DMG="build/Mochi-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -volname "Mochi" -srcfolder "$STAGE" -fs HFS+ -format UDZO -imagekey zlib-level=9 -ov "$DMG" >/dev/null
rm -rf "$(dirname "$STAGE")"
mochi_sign "$DMG"

if [[ $NOTARIZE == 1 ]]; then
    echo "▶ Notarizing the DMG…"
    mochi_notarize "$DMG"
    echo "▶ Checking with Gatekeeper…"
    spctl --assess --type open --context context:primary-signature --verbose "$DMG"
    spctl --assess --type execute --verbose build/Mochi.app
    echo "✔ $DMG ($(du -h "$DMG" | cut -f1)) — signed & notarized: every Mac will trust it"
else
    echo "✔ $DMG ($(du -h "$DMG" | cut -f1)) — NOT notarized (users will need \"Open Anyway\"). See docs/SIGNING.md"
fi
