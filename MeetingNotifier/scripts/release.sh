#!/bin/bash
#
# One-shot release automation for MeetingNotifier.
#
# Does the whole thing:
#   1. Bumps CFBundleShortVersionString + CFBundleVersion in project.yml
#   2. Regenerates Xcode project with xcodegen
#   3. Archives + exports Developer ID .app
#   4. Notarizes + staples the .app
#   5. Builds DMG, notarizes + staples DMG, Sparkle-signs it
#   6. Uploads DMG + appcast.xml to Cloudflare R2 (strategic-nerds-downloads)
#   7. Verifies everything is live
#
# Prerequisites:
#   - notarytool keychain profile "agent-server" (see SPARKLE.md)
#   - Sparkle sign_update at ~/bin/sparkle/sign_update
#   - create-dmg installed (brew install create-dmg)
#   - doppler CLI logged in with access to the meeting-notifier/prd config
#     (provides CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID, R2_BUCKET_NAME, R2_PUBLIC_BASE_URL)
#   - wrangler available (npm i -g wrangler) or npx on PATH
#   - python3 on PATH
#   - xcodegen on PATH
#
# Usage:
#   ./scripts/release.sh <version> "<release notes HTML>"
#
# Example:
#   ./scripts/release.sh 1.4.0 "<li>New feature.</li><li>Bug fixes.</li>"

set -euo pipefail

VERSION="${1:?Usage: $0 <version> \"<release notes HTML>\"}"
NOTES="${2:?Usage: $0 <version> \"<release notes HTML>\"}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$REPO_ROOT/dist"
SCRIPTS="$REPO_ROOT/scripts"

NOTARY_PROFILE="${NOTARY_PROFILE:-agent-server}"
SPARKLE_SIGN_UPDATE="${SPARKLE_SIGN_UPDATE:-$HOME/bin/sparkle/sign_update}"
SIGN_IDENTITY="Developer ID Application: Prashant Sridharan (955GSY56UT)"

APP_FOLDER="meeting-notifier"
DUB_SHORTLINK="https://coolasspuppy.com/meeting-notifier-updates"

DOPPLER_PROJECT="${DOPPLER_PROJECT:-meeting-notifier}"
DOPPLER_CONFIG="${DOPPLER_CONFIG:-prd}"

if command -v wrangler >/dev/null 2>&1; then
  WRANGLER=(wrangler)
else
  WRANGLER=(npx --yes wrangler)
fi

#----------------------------------------------------------------------
# Preflight
#----------------------------------------------------------------------
for tool in xcodebuild xcodegen create-dmg doppler python3 "$SPARKLE_SIGN_UPDATE"; do
  if ! command -v "$tool" >/dev/null 2>&1 && [ ! -x "$tool" ]; then
    echo "Error: required tool not found: $tool"
    exit 1
  fi
done

if ! "${WRANGLER[@]}" --version >/dev/null 2>&1; then
  echo "Error: wrangler not available. Install with: npm i -g wrangler"
  exit 1
fi

# Notary auth. The app-specific password is shared across the fleet and lives
# in Doppler, so pull it from there unless credentials are already supplied.
# A stored keychain profile still works, but storing one needs a GUI session —
# an automated shell can't create it. Matches command-center's release.sh.
NOTARY_APPLE_ID="${NOTARY_APPLE_ID:-prashant_sridharan@hotmail.com}"
NOTARY_TEAM_ID="${NOTARY_TEAM_ID:-955GSY56UT}"
if [ -z "${NOTARY_PASSWORD:-}" ]; then
  NOTARY_PASSWORD="$(doppler secrets get SPARKLE_APP_SPECIFIC_PASSWORD \
    --project "$DOPPLER_PROJECT" --config "$DOPPLER_CONFIG" --plain 2>/dev/null || true)"
fi
if [ -n "${NOTARY_PASSWORD:-}" ]; then
  NOTARY_AUTH=(--apple-id "$NOTARY_APPLE_ID" --team-id "$NOTARY_TEAM_ID" --password "$NOTARY_PASSWORD")
  export NOTARY_APPLE_ID NOTARY_TEAM_ID NOTARY_PASSWORD
elif xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  NOTARY_AUTH=(--keychain-profile "$NOTARY_PROFILE")
else
  echo "Error: no notary credentials."
  echo "Either set SPARKLE_APP_SPECIFIC_PASSWORD in Doppler $DOPPLER_PROJECT/$DOPPLER_CONFIG,"
  echo "or run: xcrun notarytool store-credentials \"$NOTARY_PROFILE\" --apple-id ... --team-id ... --password ..."
  exit 1
fi

mkdir -p "$DIST"

#----------------------------------------------------------------------
# 1. Bump version in project.yml
#----------------------------------------------------------------------
echo "==> Bumping version to $VERSION"
CURRENT_BUILD=$(awk -F'"' '/CFBundleVersion:/ {print $2}' "$REPO_ROOT/project.yml")
NEW_BUILD=$((CURRENT_BUILD + 1))
python3 - <<PY
import re, pathlib
p = pathlib.Path("$REPO_ROOT/project.yml")
text = p.read_text()
text = re.sub(r'CFBundleShortVersionString: "[^"]+"', 'CFBundleShortVersionString: "$VERSION"', text)
text = re.sub(r'CFBundleVersion: "[^"]+"', 'CFBundleVersion: "$NEW_BUILD"', text)
p.write_text(text)
PY
echo "  CFBundleShortVersionString=$VERSION CFBundleVersion=$NEW_BUILD"

#----------------------------------------------------------------------
# 2. Regenerate project
#----------------------------------------------------------------------
echo "==> Regenerating Xcode project"
(cd "$REPO_ROOT" && xcodegen generate)

#----------------------------------------------------------------------
# PostHog telemetry key
#----------------------------------------------------------------------
# Fetch the telemetry key from this app's Doppler project.
#
# The key used to be hardcoded in Info.plist, pointing at the Strategic Nerds
# Blog project, which is why months of menu-bar events landed in the blog's
# analytics. Info.plist now carries the $(POSTHOG_API_KEY) build setting and
# Telemetry.setup() refuses the unsubstituted placeholder, so a build without
# this step ships with capture silently disabled.
TELEMETRY_DOPPLER_PROJECT="${TELEMETRY_DOPPLER_PROJECT:-meeting-notifier}"
TELEMETRY_DOPPLER_CONFIG="${TELEMETRY_DOPPLER_CONFIG:-prd}"
export TELEMETRY_DOPPLER_PROJECT TELEMETRY_DOPPLER_CONFIG
echo "==> Loading the PostHog project key ($TELEMETRY_DOPPLER_PROJECT/$TELEMETRY_DOPPLER_CONFIG)"
POSTHOG_PUBLIC_KEY=$(doppler secrets get POSTHOG_PUBLIC_KEY \
  --project "$TELEMETRY_DOPPLER_PROJECT" --config "$TELEMETRY_DOPPLER_CONFIG" --plain 2>/dev/null || true)
if [ -z "$POSTHOG_PUBLIC_KEY" ]; then
  echo "Error: missing POSTHOG_PUBLIC_KEY in Doppler $TELEMETRY_DOPPLER_PROJECT/$TELEMETRY_DOPPLER_CONFIG"
  exit 1
fi

#----------------------------------------------------------------------
# Polar subscription config
#----------------------------------------------------------------------
# Five public values, same Doppler project and config as the PostHog key above,
# reaching Info.plist by the same route: an xcodebuild build setting substituted
# into a $(NAME) placeholder. None of them are secret; they ship inside the app
# bundle the way the OAuth client ids do.
#
# Leaving all five empty is legitimate and ships a build with no paywall and
# every calendar account unlocked, which is what a fork gets. What is NOT
# legitimate is an org id without a benefit id: Polar's license endpoint grants
# on organization membership, so that build accepts a Mail Notifier or Sync Bar
# key and gives this app away. The guard below refuses to build it.
#
# POLAR_API_BASE may be empty (PolarConfig defaults to the live API) or the live
# API spelled out. Either is production. Anything else points the build at
# Polar's sandbox, where no real money moves, so that gets a warning.
echo "==> Loading the Polar subscription config ($TELEMETRY_DOPPLER_PROJECT/$TELEMETRY_DOPPLER_CONFIG)"
polar_secret() {
  doppler secrets get "$1" \
    --project "$TELEMETRY_DOPPLER_PROJECT" --config "$TELEMETRY_DOPPLER_CONFIG" --plain 2>/dev/null || true
}
POLAR_ORG_ID=$(polar_secret POLAR_ORG_ID)
POLAR_BENEFIT_ID=$(polar_secret POLAR_BENEFIT_ID)
POLAR_CHECKOUT_URL=$(polar_secret POLAR_CHECKOUT_URL)
POLAR_PORTAL_URL=$(polar_secret POLAR_PORTAL_URL)
POLAR_API_BASE=$(polar_secret POLAR_API_BASE)

if [ -n "$POLAR_ORG_ID" ] && [ -z "$POLAR_BENEFIT_ID" ]; then
  echo "Error: POLAR_ORG_ID is set but POLAR_BENEFIT_ID is empty."
  echo "       That build sells subscriptions and accepts a license key from any"
  echo "       Strategic Nerds app. See tasks/polar-setup.md, section 1.5."
  exit 1
fi

if [ -z "$POLAR_ORG_ID" ]; then
  echo "    No Polar org configured. Building with no paywall, every account unlocked."
else
  echo "    Polar org $POLAR_ORG_ID, benefit $POLAR_BENEFIT_ID"
  case "$POLAR_API_BASE" in
    ""|"https://api.polar.sh") ;;
    *) echo "    WARNING: POLAR_API_BASE is $POLAR_API_BASE, not the live API." ;;
  esac
fi

#----------------------------------------------------------------------
# 3. Archive
#----------------------------------------------------------------------
ARCHIVE="$DIST/MeetingNotifier-$VERSION.xcarchive"
rm -rf "$ARCHIVE"
echo "==> Archiving"
xcodebuild -project "$REPO_ROOT/MeetingNotifier.xcodeproj" \
  -scheme MeetingNotifier \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  POSTHOG_API_KEY="$POSTHOG_PUBLIC_KEY" \
  POLAR_ORG_ID="$POLAR_ORG_ID" \
  POLAR_BENEFIT_ID="$POLAR_BENEFIT_ID" \
  POLAR_CHECKOUT_URL="$POLAR_CHECKOUT_URL" \
  POLAR_PORTAL_URL="$POLAR_PORTAL_URL" \
  POLAR_API_BASE="$POLAR_API_BASE" \
  archive | xcpretty 2>/dev/null || \
xcodebuild -project "$REPO_ROOT/MeetingNotifier.xcodeproj" \
  -scheme MeetingNotifier \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  POSTHOG_API_KEY="$POSTHOG_PUBLIC_KEY" \
  POLAR_ORG_ID="$POLAR_ORG_ID" \
  POLAR_BENEFIT_ID="$POLAR_BENEFIT_ID" \
  POLAR_CHECKOUT_URL="$POLAR_CHECKOUT_URL" \
  POLAR_PORTAL_URL="$POLAR_PORTAL_URL" \
  POLAR_API_BASE="$POLAR_API_BASE" \
  archive >/dev/null

#----------------------------------------------------------------------
# 4. Export Developer ID .app
#----------------------------------------------------------------------
EXPORT_DIR="$DIST/export-$VERSION"
rm -rf "$EXPORT_DIR"
echo "==> Exporting .app"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$SCRIPTS/export-options.plist" \
  -allowProvisioningUpdates >/dev/null

APP_PATH="$EXPORT_DIR/MeetingNotifier.app"
if [ ! -d "$APP_PATH" ]; then
  echo "Error: export did not produce $APP_PATH"
  exit 1
fi

#----------------------------------------------------------------------
# 4a. Refuse to ship a credential compiled into the binary
#----------------------------------------------------------------------
# Runs on the exported Release .app, before notarizing, because notarizing and
# uploading are the irreversible steps. gitignore has always covered
# *Secret.swift and the values were never committed, so every repo-level check
# passed while secrets shipped inside the DMG. Nothing looked at the artifact.
"$SCRIPTS/check-no-secrets.sh" "$APP_PATH"

#----------------------------------------------------------------------
# 5. Notarize + staple the .app
#----------------------------------------------------------------------
echo "==> Notarizing .app (takes a few minutes)"
APP_ZIP="$EXPORT_DIR/MeetingNotifier.app.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$APP_ZIP"
xcrun notarytool submit "$APP_ZIP" "${NOTARY_AUTH[@]}" --wait
rm -f "$APP_ZIP"

echo "==> Stapling .app"
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

#----------------------------------------------------------------------
# 6. DMG + notarize + staple + Sparkle sign
#----------------------------------------------------------------------
echo "==> Building DMG"
"$SCRIPTS/build-dmg.sh" "$APP_PATH" "$VERSION" "$NOTARY_PROFILE"

DMG="$DIST/MeetingNotifier-$VERSION.dmg"
SPARKLE_TXT="$DIST/MeetingNotifier-$VERSION.sparkle.txt"

if [ ! -f "$DMG" ] || [ ! -f "$SPARKLE_TXT" ]; then
  echo "Error: DMG or sparkle signature missing after build-dmg.sh"
  exit 1
fi

#----------------------------------------------------------------------
# 7. Fetch Cloudflare R2 credentials from Doppler
#----------------------------------------------------------------------
echo "==> Fetching Cloudflare R2 credentials from Doppler ($DOPPLER_PROJECT/$DOPPLER_CONFIG)"
export CLOUDFLARE_API_TOKEN
CLOUDFLARE_API_TOKEN=$(doppler secrets get CLOUDFLARE_API_TOKEN \
  --project "$DOPPLER_PROJECT" --config "$DOPPLER_CONFIG" --plain 2>/dev/null || true)
export CLOUDFLARE_ACCOUNT_ID
CLOUDFLARE_ACCOUNT_ID=$(doppler secrets get CLOUDFLARE_ACCOUNT_ID \
  --project "$DOPPLER_PROJECT" --config "$DOPPLER_CONFIG" --plain 2>/dev/null || true)
R2_BUCKET=$(doppler secrets get R2_BUCKET_NAME \
  --project "$DOPPLER_PROJECT" --config "$DOPPLER_CONFIG" --plain 2>/dev/null || echo "strategic-nerds-downloads")
R2_PUBLIC_BASE=$(doppler secrets get R2_PUBLIC_BASE_URL \
  --project "$DOPPLER_PROJECT" --config "$DOPPLER_CONFIG" --plain 2>/dev/null || echo "https://downloads.strategicnerds.com")

if [ -z "$CLOUDFLARE_API_TOKEN" ] || [ -z "$CLOUDFLARE_ACCOUNT_ID" ]; then
  echo "Error: missing CLOUDFLARE_API_TOKEN or CLOUDFLARE_ACCOUNT_ID in Doppler $DOPPLER_PROJECT/$DOPPLER_CONFIG"
  exit 1
fi

#----------------------------------------------------------------------
# 8. Upload DMG to R2
#----------------------------------------------------------------------
DMG_NAME="MeetingNotifier-$VERSION.dmg"
R2_DMG_KEY="apps/$APP_FOLDER/$DMG_NAME"
echo "==> Uploading $DMG_NAME to R2 ($R2_BUCKET/$R2_DMG_KEY)"
"${WRANGLER[@]}" r2 object put "$R2_BUCKET/$R2_DMG_KEY" \
  --file="$DMG" \
  --content-type="application/x-apple-diskimage" \
  --remote

# Also upload as MeetingNotifier-latest.dmg so the strategic-nerds site has a stable URL
R2_LATEST_KEY="apps/$APP_FOLDER/MeetingNotifier-latest.dmg"
echo "==> Uploading latest.dmg alias to R2 ($R2_BUCKET/$R2_LATEST_KEY)"
"${WRANGLER[@]}" r2 object put "$R2_BUCKET/$R2_LATEST_KEY" \
  --file="$DMG" \
  --content-type="application/x-apple-diskimage" \
  --remote

#----------------------------------------------------------------------
# 9. Update appcast.xml and upload to R2
#----------------------------------------------------------------------
APPCAST="$DIST/appcast.xml"
echo "==> Prepending new <item> to appcast.xml"

ED_SIG=$(grep -oE 'sparkle:edSignature="[^"]+"' "$SPARKLE_TXT" | sed -E 's/.*"([^"]+)"/\1/')
LENGTH=$(grep -oE 'length="[^"]+"' "$SPARKLE_TXT" | sed -E 's/.*"([^"]+)"/\1/')
PUB_DATE=$(LC_ALL=C date -u +"%a, %d %b %Y %H:%M:%S +0000")
ENCLOSURE_URL="$R2_PUBLIC_BASE/apps/$APP_FOLDER/$DMG_NAME"

python3 - <<PY
import pathlib, re

p = pathlib.Path("$APPCAST")
xml = p.read_text()

new_item = f'''    <item>
      <title>Version $VERSION</title>
      <pubDate>$PUB_DATE</pubDate>
      <sparkle:version>$NEW_BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>26.0</sparkle:minimumSystemVersion>
      <description><![CDATA[
        <ul>
          $NOTES
        </ul>
      ]]></description>
      <enclosure
        url="$ENCLOSURE_URL"
        sparkle:edSignature="$ED_SIG"
        length="$LENGTH"
        type="application/x-apple-diskimage" />
    </item>
'''

marker = "<language>en</language>"
if marker not in xml:
    raise SystemExit("Could not find <language>en</language> insertion point in appcast.xml")
xml = xml.replace(marker, marker + "\n" + new_item, 1)
p.write_text(xml)
PY

R2_APPCAST_KEY="apps/$APP_FOLDER/appcast.xml"
echo "==> Uploading appcast.xml to R2 ($R2_BUCKET/$R2_APPCAST_KEY)"
"${WRANGLER[@]}" r2 object put "$R2_BUCKET/$R2_APPCAST_KEY" \
  --file="$APPCAST" \
  --content-type="application/xml; charset=utf-8" \
  --remote

#----------------------------------------------------------------------
# 10. Verify
#----------------------------------------------------------------------
echo ""
echo "==> Verifying uploaded DMG"
curl -sI "$ENCLOSURE_URL" | grep -iE '^(HTTP|content-length)'
echo ""
echo "==> Verifying appcast at R2"
curl -sI "$R2_PUBLIC_BASE/$R2_APPCAST_KEY" | grep -iE '^(HTTP|content-length)'
echo ""
echo "==> Verifying appcast via Dub shortlink"
curl -sL "$DUB_SHORTLINK" | grep -E '<(title|sparkle:shortVersionString|enclosure)' | head -6

echo ""
echo "============================================================"
echo "Released MeetingNotifier $VERSION (build $NEW_BUILD)"
echo ""
echo "Local artifacts:"
echo "  $DMG"
echo "  $SPARKLE_TXT"
echo "  $APPCAST"
echo ""
echo "Live:"
echo "  $ENCLOSURE_URL"
echo "  $R2_PUBLIC_BASE/$R2_APPCAST_KEY"
echo "  $DUB_SHORTLINK"
echo ""
echo "Don't forget to commit: project.yml + dist/appcast.xml"
echo "============================================================"
