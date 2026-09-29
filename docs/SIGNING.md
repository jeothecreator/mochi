# Making every Mac trust Mochi (signing + notarization)

macOS only opens downloaded apps without warnings when they are **signed with a Developer ID certificate**
and **notarized by Apple**. The build scripts already do both automatically — they just need two things
that only the developer can set up, once.

## 1. Join the Apple Developer Program

- Enroll at <https://developer.apple.com/programs/enroll/> — **$99/year**, individual enrollment is fine.
- Approval can take from minutes to a couple of days.
- Only the team's **Account Holder** can create Developer ID certificates. (If you're using a family member's
  team, they need to do step 2, or enroll yourself.)

## 2. Create a "Developer ID Application" certificate

Easiest, in Xcode:

1. **Xcode → Settings → Accounts**, add your Apple ID, select the team.
2. **Manage Certificates… → + → Developer ID Application**.

Check it's installed:

```bash
security find-identity -v -p codesigning | grep "Developer ID Application"
```

## 3. Save notarization credentials in your Keychain

Create an **app-specific password** at <https://account.apple.com> → Sign-In and Security → App-Specific Passwords.
Then run this yourself (it asks for your Apple ID, Team ID and the app-specific password, and stores them in
the Keychain — the scripts never see them):

```bash
xcrun notarytool store-credentials mochi-notary
```

Your Team ID is shown at <https://developer.apple.com/account> → Membership details.

## 4. Build a trusted release

```bash
MOCHI_VERSION=1.1.1 ./scripts/make-dmg.sh
```

With the certificate and the `mochi-notary` profile in place, the script:

1. signs `Mochi.app` with your Developer ID (hardened runtime + secure timestamp),
2. notarizes the app and staples the ticket (so it also opens offline),
3. builds, signs, notarizes and staples the DMG,
4. verifies both with Gatekeeper (`spctl`) — it should say `source=Notarized Developer ID`.

Without them it still builds, ad-hoc signed, and says "NOT notarized".

Overrides: `MOCHI_SIGN_IDENTITY="Developer ID Application: Name (TEAMID)"`, `MOCHI_NOTARY_PROFILE=other-profile`.

## After the first notarized release

- Drop the "Open Anyway" steps from the README, the release notes and the Homebrew cask `caveats`.
- Homebrew users still need `brew trust` (that's Homebrew's own rule for third-party taps, not Apple's).
