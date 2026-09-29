#!/bin/bash
# Shared signing helpers (sourced by build-app.sh and make-dmg.sh).
#
# With a "Developer ID Application" certificate in your keychain, Mochi is signed with it
# (hardened runtime + secure timestamp) and can be notarized so every Mac trusts it.
# Without one, it falls back to ad-hoc signing (works, but Gatekeeper asks users to "Open Anyway").
#
#   MOCHI_SIGN_IDENTITY   override the certificate name (default: first "Developer ID Application" found)
#   MOCHI_NOTARY_PROFILE  notarytool keychain profile (default: mochi-notary)

MOCHI_NOTARY_PROFILE="${MOCHI_NOTARY_PROFILE:-mochi-notary}"

mochi_identity() {
    if [[ -n "${MOCHI_SIGN_IDENTITY:-}" ]]; then
        echo "$MOCHI_SIGN_IDENTITY"
        return
    fi
    security find-identity -v -p codesigning 2>/dev/null \
        | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1
}

# mochi_sign <path> — signs an .app or .dmg with the best identity available.
mochi_sign() {
    local target="$1" identity
    identity="$(mochi_identity)"
    if [[ -n "$identity" ]]; then
        if [[ "$target" == *.app ]]; then
            codesign --force --options runtime --timestamp --sign "$identity" "$target"
        else
            codesign --force --timestamp --sign "$identity" "$target"
        fi
    elif [[ "$target" == *.app ]]; then
        codesign --force --options runtime --sign - "$target"
    fi
    return 0
}

mochi_can_notarize() {
    [[ -n "$(mochi_identity)" ]] && xcrun notarytool history --keychain-profile "$MOCHI_NOTARY_PROFILE" >/dev/null 2>&1
}

# mochi_notarize <path> — uploads to Apple's notary service, waits, and staples the ticket.
mochi_notarize() {
    local target="$1" upload="$1"
    if [[ "$target" == *.app ]]; then
        upload="$(mktemp -d)/$(basename "$target" .app).zip"
        ditto -c -k --keepParent "$target" "$upload"
    fi
    echo "  ↑ Sending $(basename "$target") to Apple's notary service (usually 1–5 minutes)…"
    if ! xcrun notarytool submit "$upload" --keychain-profile "$MOCHI_NOTARY_PROFILE" --wait; then
        echo "✘ Notarization failed. See the log with: xcrun notarytool log <submission-id> --keychain-profile $MOCHI_NOTARY_PROFILE"
        return 1
    fi
    xcrun stapler staple "$target"
}
