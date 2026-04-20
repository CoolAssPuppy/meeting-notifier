#!/bin/bash
#
# Build a distributable, notarized, Sparkle-signed DMG for MeetingNotifier.
#
# Prerequisites:
#   1. Xcode Archive + Developer ID export of "MeetingNotifier.app" (the .app
#      must already be signed with Developer ID and notarized+stapled).
#   2. `brew install create-dmg`
#   3. Background TIFF at dmg-assets/background.tiff (see dmg-assets/README.md).
#   4. A `notarytool` keychain profile stored via:
#        xcrun notarytool store-credentials <profile-name> --apple-id ... --team-id ... --password ...
#   5. Sparkle `sign_update` tool at ~/bin/sparkle/sign_update (see SPARKLE.md).
#
# Usage:
#   ./scripts/build-dmg.sh <path-to-MeetingNotifier.app> <version> <notarytool-profile>
#
# Output:
#   dist/MeetingNotifier-<version>.dmg             (signed, notarized, stapled)
#   dist/MeetingNotifier-<version>.sparkle.txt     (edSignature + length for appcast)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:?Usage: $0 <path-to-MeetingNotifier.app> <version> <notarytool-profile>}"
VERSION="${2:?Usage: $0 <path-to-MeetingNotifier.app> <version> <notarytool-profile>}"
NOTARY_PROFILE="${3:?Usage: $0 <path-to-MeetingNotifier.app> <version> <notarytool-profile>}"

SIGN_UPDATE="${SPARKLE_SIGN_UPDATE:-$HOME/bin/sparkle/sign_update}"
SPARKLE_KEY_ACCOUNT="${SPARKLE_KEY_ACCOUNT:-com.strategicnerds.meetingnotifier}"

BACKGROUND="$REPO_ROOT/dmg-assets/background.tiff"
DMG_OUT="$REPO_ROOT/dist/MeetingNotifier-$VERSION.dmg"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Error: App not found at $APP_PATH"
  exit 1
fi

if [[ ! -f "$BACKGROUND" ]]; then
  echo "Error: Background TIFF not found at $BACKGROUND"
  echo "See dmg-assets/README.md for how to generate one from a 1320x800 PNG."
  exit 1
fi

if ! command -v create-dmg >/dev/null 2>&1; then
  echo "Error: create-dmg not installed. Run: brew install create-dmg"
  exit 1
fi

if [[ ! -x "$SIGN_UPDATE" ]]; then
  echo "Error: Sparkle sign_update not found at $SIGN_UPDATE"
  echo "Install it (see SPARKLE.md) or set SPARKLE_SIGN_UPDATE to its path."
  exit 1
fi

mkdir -p "$REPO_ROOT/dist"
rm -f "$DMG_OUT"

echo "Building DMG for MeetingNotifier v$VERSION..."
echo "  App:        $APP_PATH"
echo "  Background: $BACKGROUND"
echo "  Output:     $DMG_OUT"
echo ""

# Window coords assume a 1320x800 (2x retina) background → 660x400 window.
# Update if the art changes.
create-dmg \
  --volname "MeetingNotifier" \
  --background "$BACKGROUND" \
  --window-pos 200 120 \
  --window-size 660 400 \
  --icon-size 96 \
  --icon "MeetingNotifier.app" 400 200 \
  --app-drop-link 565 200 \
  --hide-extension "MeetingNotifier.app" \
  --no-internet-enable \
  --hdiutil-quiet \
  "$DMG_OUT" \
  "$APP_PATH"

echo ""
echo "DMG built: $DMG_OUT"
echo ""

SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: Prashant Sridharan (955GSY56UT)}"
echo "Codesigning DMG with: $SIGN_IDENTITY"
codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG_OUT"

echo "Notarizing DMG (this can take several minutes)..."
xcrun notarytool submit "$DMG_OUT" --keychain-profile "$NOTARY_PROFILE" --wait

echo ""
echo "Stapling notarization ticket..."
xcrun stapler staple "$DMG_OUT"

echo ""
echo "Verifying notarization..."
xcrun stapler validate "$DMG_OUT"
spctl -a -t open --context context:primary-signature -v "$DMG_OUT"

echo ""
echo "Signing DMG with Sparkle (account: $SPARKLE_KEY_ACCOUNT)..."
SPARKLE_OUT="${DMG_OUT%.dmg}.sparkle.txt"
"$SIGN_UPDATE" --account "$SPARKLE_KEY_ACCOUNT" "$DMG_OUT" | tee "$SPARKLE_OUT"

echo ""
echo "============================================================"
echo "Release artifacts for v$VERSION"
echo "============================================================"
echo "  DMG:           $DMG_OUT"
echo "  Sparkle info:  $SPARKLE_OUT"
