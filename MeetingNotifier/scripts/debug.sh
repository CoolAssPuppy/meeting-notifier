#!/bin/bash
#
# Build a local Debug copy of MeetingNotifier and launch it, without opening Xcode.
#
# Usage:
#   ./scripts/debug.sh              # build and launch
#   ./scripts/debug.sh --no-launch  # build only, don't open the app
#   ./scripts/debug.sh --polar      # bake in the Polar SANDBOX config too
#
# Output:
#   dist/debug/MeetingNotifier.app
#
# Without --polar the build has no Polar config, so there is no paywall and
# every calendar account runs. That is the right default for day-to-day work and
# it is also what a fork gets. Pass --polar to exercise the subscription against
# Polar's sandbox, which reads the five POLAR_* values from Doppler
# meeting-notifier/dev. Back up your state first: the Debug build shares a bundle
# id with the copy in /Applications, so your real second and third accounts go
# Locked the moment it launches without a license. See scripts/test-state.sh.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$REPO_ROOT/dist/debug"
DERIVED="$REPO_ROOT/build/DerivedData"

LAUNCH=1
POLAR=0
for arg in "$@"; do
  case "$arg" in
    --no-launch) LAUNCH=0 ;;
    --polar)     POLAR=1 ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

POLAR_SETTINGS=()
if [[ "$POLAR" == "1" ]]; then
  if ! command -v doppler >/dev/null 2>&1; then
    echo "Error: --polar needs the doppler CLI. Run: brew install dopplerhq/cli/doppler"
    exit 1
  fi
  DOPPLER_CONFIG_NAME="${POLAR_DOPPLER_CONFIG:-dev}"
  echo "==> Loading the Polar sandbox config (meeting-notifier/$DOPPLER_CONFIG_NAME)"
  for key in POLAR_ORG_ID POLAR_BENEFIT_ID POLAR_CHECKOUT_URL POLAR_PORTAL_URL POLAR_API_BASE; do
    value="$(doppler secrets get "$key" --project meeting-notifier \
      --config "$DOPPLER_CONFIG_NAME" --plain 2>/dev/null || true)"
    POLAR_SETTINGS+=("$key=$value")
  done
  # The pin is what stops a Mail Notifier or Sync Bar key from unlocking this
  # app, and testing without it tests nothing. See tasks/polar-setup.md.
  if [[ " ${POLAR_SETTINGS[*]} " == *"POLAR_BENEFIT_ID= "* ]]; then
    echo "    WARNING: POLAR_BENEFIT_ID is empty. Any Strategic Nerds key will unlock this build."
  fi
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Error: xcodegen not installed. Run: brew install xcodegen"
  exit 1
fi

echo "==> Regenerating Xcode project"
(cd "$REPO_ROOT" && xcodegen generate >/dev/null)

echo "==> Building (Debug)"
xcodebuild \
  -project "$REPO_ROOT/MeetingNotifier.xcodeproj" \
  -scheme MeetingNotifier \
  -configuration Debug \
  -derivedDataPath "$DERIVED" \
  -quiet \
  "${POLAR_SETTINGS[@]+"${POLAR_SETTINGS[@]}"}" \
  build

SRC_APP="$DERIVED/Build/Products/Debug/MeetingNotifier.app"
if [[ ! -d "$SRC_APP" ]]; then
  echo "Error: expected built app at $SRC_APP but it's not there."
  exit 1
fi

mkdir -p "$DIST"
rm -rf "$DIST/MeetingNotifier.app"
ditto "$SRC_APP" "$DIST/MeetingNotifier.app"

# Both the DerivedData copy and dist/debug copy share the same bundle ID and
# URL schemes. If both stay registered with LaunchServices, macOS may route
# OAuth callbacks to the wrong one and the auth flow will "hang" — the app
# that doesn't own the pending AppAuth session silently drops the callback.
# Remove and unregister the DerivedData copy so dist/debug is the sole handler,
# then force a fresh registration of dist/debug to make it the preferred handler.
LSREG="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
"$LSREG" -u "$SRC_APP" >/dev/null 2>&1 || true
rm -rf "$SRC_APP"
"$LSREG" -f "$DIST/MeetingNotifier.app" >/dev/null 2>&1 || true

echo ""
echo "Built: $DIST/MeetingNotifier.app"

if [[ "$LAUNCH" == "1" ]]; then
  # Kill any running copy so the new binary takes over.
  pkill -x "MeetingNotifier" 2>/dev/null || true
  sleep 1
  open "$DIST/MeetingNotifier.app"
  echo "Launched."
fi
